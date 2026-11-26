#!/usr/bin/env bash
# Prepares and pushes a release: bumps the version, updates the changelog,
# runs CI, commits, tags and (after confirmation) pushes. Pushing the tag
# starts .github/workflows/release.yml (GitHub release) and
# .github/workflows/publish.yml (pub.dev, behind the 'pub.dev' environment).
#
# Safe to re-run: steps that are already done (version bumped, commit made,
# tag created, tag pushed) are detected and skipped.
source "$(dirname "$0")/lib/common.sh"

usage() {
  cat <<USAGE
Usage: ./scripts/release.sh (--patch | --minor | --major | --version X.Y.Z) [--dry-run] [--skip-ci] [--yes]

  --patch / --minor / --major   Bump from the current pubspec.yaml version.
  --version X.Y.Z               Release an explicit version (may equal the
                                current one, for example the first release).
  --dry-run                     Show what would happen; change nothing.
  --skip-ci                     Skip ./scripts/ci.sh (not recommended).
  --yes                         Answer the push confirmation with yes.
  -h, --help                    Show this help.

Before tagging, CHANGELOG.md must contain either '## Unreleased' (renamed to
the new version) or a '## X.Y.Z' section.
USAGE
}

bump="" explicit="" dry_run=false skip_ci=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --patch|--minor|--major) bump="${1#--}" ;;
    --version) explicit="${2:?--version needs a value}"; shift ;;
    --dry-run) dry_run=true ;;
    --skip-ci) skip_ci=true ;;
    --yes) ASSUME_YES=1 ;;
    -h|--help) usage; exit 0 ;;
    *) usage; fail "Unknown option: $1" ;;
  esac
  shift
done
[[ -n "$bump" || -n "$explicit" ]] || { usage; fail "Choose --patch, --minor, --major or --version"; }
[[ -n "$bump" && -n "$explicit" ]] && fail "Use either a bump flag or --version, not both"

stage="start"
trap 'warn "Release stopped during: $stage"; warn "Nothing was pushed unless the push stage completed. Fix the problem and re-run the same command; finished steps are skipped."' ERR

# 1-2. Working directory and tools -------------------------------------------
stage="tool validation"
step "Checking tools"
require git flutter dart
ok "git, flutter and dart available"

# 3. Branch --------------------------------------------------------------------
stage="branch check"
branch="$(git rev-parse --abbrev-ref HEAD)"
[[ "$branch" == "main" ]] || fail "Releases are made from 'main' (current: $branch)"
ok "On branch main"

# 4. Clean tree ----------------------------------------------------------------
stage="working tree check"
current="$(package_version)"
if [[ -n "$(git status --porcelain)" ]]; then
  fail "Working tree is not clean. Commit or stash your changes first."
fi
ok "Working tree clean"

# 5. Remote sync ---------------------------------------------------------------
stage="remote sync check"
if git remote get-url origin >/dev/null 2>&1; then
  git fetch --quiet --tags origin main || fail "Could not fetch from origin"
  if git rev-parse --verify --quiet origin/main >/dev/null; then
    behind="$(git rev-list --count HEAD..origin/main)"
    [[ "$behind" == "0" ]] || fail "main is $behind commit(s) behind origin/main; pull first"
  fi
  ok "In sync with origin"
else
  fail "No 'origin' remote configured"
fi

# 6-7. Version -----------------------------------------------------------------
stage="version calculation"
is_semver "$current" || fail "Current version '$current' is not semantic"
if [[ -n "$explicit" ]]; then
  next="$explicit"
else
  IFS=.- read -r major minor patch _ <<<"$current"
  case "$bump" in
    patch) next="$major.$minor.$((patch + 1))" ;;
    minor) next="$major.$((minor + 1)).0" ;;
    major) next="$((major + 1)).0.0" ;;
  esac
fi
is_semver "$next" || fail "'$next' is not a semantic version"
tag="v$next"
already_published=false
if published_versions | grep -qx "$next"; then
  already_published=true
  warn "$next is already on pub.dev (for example after the initial manual publish)."
  warn "The publish workflow will skip it; this run only tags and creates the GitHub release."
fi
if git ls-remote --exit-code --tags origin "refs/tags/$tag" >/dev/null 2>&1; then
  remote_tag=true
else
  remote_tag=false
fi
ok "Releasing $current -> $next (tag $tag)"

if $dry_run; then
  step "Dry run summary"
  info "Would set pubspec.yaml version to $next"
  info "Would rename '## Unreleased' in CHANGELOG.md to '## $next' (or require '## $next')"
  info "Would run ./scripts/ci.sh --all, commit 'chore(release): prepare $tag', tag $tag and push"
  $remote_tag && warn "Tag $tag already exists on origin"
  ok "Dry run complete; nothing changed"
  exit 0
fi

# 8-10. Files ------------------------------------------------------------------
stage="updating files"
if [[ "$current" != "$next" ]]; then
  step "Updating pubspec.yaml"
  sed -i.bak "s/^version: .*/version: $next/" pubspec.yaml && rm pubspec.yaml.bak
  ok "pubspec.yaml version $next"
fi
if grep -q '^## Unreleased$' CHANGELOG.md; then
  step "Updating CHANGELOG.md"
  sed -i.bak "s/^## Unreleased\$/## $next/" CHANGELOG.md && rm CHANGELOG.md.bak
  ok "CHANGELOG.md section renamed to $next"
fi
grep -q "^## $next\$" CHANGELOG.md || fail "CHANGELOG.md has no '## $next' section; add release notes first"

# 11-12. Checks ----------------------------------------------------------------
stage="CI checks"
if $skip_ci; then
  warn "Skipping CI checks (--skip-ci)"
  "$REPO_ROOT/scripts/validate_package.sh"
else
  "$REPO_ROOT/scripts/ci.sh" --all
fi

# 13. Release notes ------------------------------------------------------------
stage="release notes"
notes="$(awk -v v="## $next" '$0 == v {flag=1; next} /^## /{flag=0} flag' CHANGELOG.md)"
[[ -n "${notes//[[:space:]]/}" ]] || fail "The CHANGELOG section for $next is empty"

# 14-15. Summary and confirmation ----------------------------------------------
step "Release summary"
info "Version:  $next"
info "Tag:      $tag"
info "Branch:   main -> origin"
info "Notes:"
printf '%s\n' "$notes" | sed 's/^/      /'
echo
info "Pushing the tag starts the GitHub release and the pub.dev publish workflows."
if $already_published; then
  info "pub.dev already has $next, so the publish workflow will skip it."
else
  info "Publishing additionally waits for approval in the 'pub.dev' environment."
fi
confirm "Commit, tag and push $tag now?" || { warn "Cancelled. Local file changes are kept; revert them with 'git checkout -- pubspec.yaml CHANGELOG.md' if needed."; exit 1; }

# 16. Commit -------------------------------------------------------------------
stage="release commit"
if [[ -n "$(git status --porcelain pubspec.yaml CHANGELOG.md)" ]]; then
  git add pubspec.yaml CHANGELOG.md
  git commit -m "chore(release): prepare $tag"
  ok "Created release commit"
else
  ok "Release files already committed"
fi

# 17. Tag ----------------------------------------------------------------------
stage="tagging"
if git rev-parse -q --verify "refs/tags/$tag" >/dev/null; then
  [[ "$(git rev-list -n1 "$tag")" == "$(git rev-parse HEAD)" ]] \
    || fail "Local tag $tag exists on another commit; inspect it manually (it is never deleted automatically)"
  ok "Tag $tag already exists on HEAD"
else
  git tag -a "$tag" -m "$tag"
  ok "Created annotated tag $tag"
fi

# 18-19. Push (starts the release and publish workflows) -----------------------
stage="push"
git push origin main
if $remote_tag; then
  ok "Tag $tag already on origin"
else
  git push origin "$tag"
  ok "Pushed $tag"
fi

# 20-21. Follow-up -------------------------------------------------------------
stage="verification"
step "Next steps"
info "GitHub release:  created by the Release workflow"
info "pub.dev publish: approve the 'pub.dev' environment in the Publish workflow"
if command -v gh >/dev/null 2>&1; then
  info "Follow progress with: gh run list --workflow publish.yml"
fi
info "Verify afterwards with: ./scripts/publish.sh --verify"
trap - ERR
ok "Release $tag pushed"
