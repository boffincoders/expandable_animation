#!/usr/bin/env bash
# Validates package metadata, documentation files and publishing readiness
# with 'dart pub publish --dry-run'. Never publishes.
source "$(dirname "$0")/lib/common.sh"

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  echo "Usage: ./scripts/validate_package.sh"
  exit 0
fi

step "Validating package metadata"
version="$(package_version)"
is_semver "$version" || fail "pubspec.yaml version '$version' is not semantic"
ok "Version $version"

description="$(awk '/^description:/{flag=1; sub(/^description:[[:space:]]*>?-?[[:space:]]*/, ""); if ($0 != "") print; next} flag && /^[[:space:]]/{print; next} flag{exit}' pubspec.yaml | tr -s '[:space:]' ' ' | sed 's/^ //; s/ $//')"
length=${#description}
(( length >= 60 && length <= 180 )) || fail "Description is $length characters; pub.dev expects 60-180"
ok "Description length $length"

topics="$(awk '/^topics:/{flag=1; next} flag && /^[[:space:]]+-/{print $2; next} flag{exit}' pubspec.yaml)"
count=0
while read -r topic; do
  [[ -z "$topic" ]] && continue
  count=$((count + 1))
  [[ "$topic" =~ ^[a-z][a-z0-9-]{0,30}[a-z0-9]$ ]] || fail "Invalid topic: $topic"
done <<<"$topics"
(( count <= 5 )) || fail "pub.dev allows at most 5 topics, found $count"
ok "$count topics"

for key in repository issue_tracker; do
  grep -q "^$key: https://" pubspec.yaml || fail "pubspec.yaml is missing '$key'"
done
for file in README.md CHANGELOG.md LICENSE; do
  [[ -s "$file" ]] || fail "Missing $file"
done
grep -q "^## $version\$" CHANGELOG.md || fail "CHANGELOG.md has no '## $version' section"
ok "README, CHANGELOG and LICENSE present"

step "Checking for files that must not be published"
for path in docs; do
  grep -qx "$path/\?" .pubignore 2>/dev/null || grep -qx "$path" .pubignore || fail ".pubignore must exclude $path"
done
ok ".pubignore excludes private developer notes"

step "Running 'dart pub publish --dry-run' on a clean export"
export_dir="$(export_package_tree)"
trap 'rm -rf "$export_dir"' EXIT
(cd "$export_dir" && run dart pub publish --dry-run)
ok "Package is ready to publish"
