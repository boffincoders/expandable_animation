#!/usr/bin/env bash
# Publishing helper. The authoritative publishing path is the GitHub Actions
# workflow .github/workflows/publish.yml, triggered by a version tag. This
# script validates locally and never races that workflow:
#
#   --dry-run   Validate metadata, version and package contents (default).
#   --verify    Check that the current version is live on pub.dev and GitHub.
#   --initial   One-time manual publish of the FIRST version, required before
#               pub.dev allows automated publishing. Refuses if the package
#               already exists on pub.dev.
source "$(dirname "$0")/lib/common.sh"

usage() {
  sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
  echo "Usage: ./scripts/publish.sh [--dry-run | --verify | --initial] [--yes]"
  echo "  --yes  answer the confirmation prompt with yes (for non-interactive runs)"
}

mode="dry-run"
for arg in "$@"; do
  case "$arg" in
    --dry-run) mode="dry-run" ;;
    --verify) mode="verify" ;;
    --initial) mode="initial" ;;
    --yes) ASSUME_YES=1 ;;
    -h|--help) usage; exit 0 ;;
    *) usage; fail "Unknown option: $arg" ;;
  esac
done

require dart flutter curl
version="$(package_version)"
name="$(package_name)"
is_semver "$version" || fail "pubspec.yaml version '$version' is not semantic"
published="$(published_versions)"

if [[ "$mode" == "verify" ]]; then
  step "Verifying $name $version"
  if grep -qx "$version" <<<"$published"; then
    ok "pub.dev lists $version: https://pub.dev/packages/$name/versions/$version"
  else
    fail "$version is not on pub.dev yet (it can take a few minutes after the workflow finishes)"
  fi
  if command -v gh >/dev/null 2>&1 && gh release view "v$version" >/dev/null 2>&1; then
    ok "GitHub release v$version exists"
  else
    warn "Could not confirm the GitHub release v$version (gh missing, unauthenticated or release absent)"
  fi
  exit 0
fi

step "Checking version $version"
if grep -qx "$version" <<<"$published"; then
  fail "$version is already published on pub.dev; bump the version with ./scripts/release.sh"
fi
ok "$version is not on pub.dev yet"

"$REPO_ROOT/scripts/validate_package.sh"

step "Package contents"
info "Files excluded by .pubignore are not uploaded. Review the file list printed by the dry run above."

if [[ "$mode" == "dry-run" ]]; then
  ok "Dry run passed. Publish by pushing the release tag with ./scripts/release.sh."
  exit 0
fi

# --initial ---------------------------------------------------------------------
step "Initial manual publish"
if [[ -n "$published" ]]; then
  fail "$name already exists on pub.dev. New versions are published only by the GitHub Actions workflow."
fi
[[ -z "$(git status --porcelain)" ]] || fail "Working tree is not clean"
[[ "$(git rev-parse --abbrev-ref HEAD)" == "main" ]] || fail "Publish from the main branch"
info "This uploads $name $version to pub.dev under your logged-in pub.dev account."
info "Publishing is permanent: a version can be retracted but never replaced or deleted."
confirm "Publish $name $version to pub.dev now?" || fail "Cancelled"
export_dir="$(export_package_tree)"
trap 'rm -rf "$export_dir"' EXIT
# The confirmation above is the gate; --force skips pub's second prompt.
(cd "$export_dir" && run dart pub publish --force)
ok "Published $version."
info "Next: run ./scripts/release.sh --version $version to tag it and create the GitHub release,"
info "then enable automated publishing on pub.dev (see .github/workflows/publish.yml)."

