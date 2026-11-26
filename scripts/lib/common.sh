#!/usr/bin/env bash
# Shared helpers for the expandable_animation scripts. Source, do not run.

set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
EXAMPLE_DIR="$REPO_ROOT/example"
WEBSITE_DIR="$REPO_ROOT/website"
SITE_OUT="$REPO_ROOT/build/site"
PAGES_BASE_PATH="/expandable_animation/"
PAGES_URL="https://boffincoders.github.io/expandable_animation/"

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  C_BLUE=$'\033[34m'; C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'
  C_RED=$'\033[31m'; C_BOLD=$'\033[1m'; C_RESET=$'\033[0m'
else
  C_BLUE=""; C_GREEN=""; C_YELLOW=""; C_RED=""; C_BOLD=""; C_RESET=""
fi

step()  { printf '\n%s==> %s%s\n' "$C_BOLD$C_BLUE" "$*" "$C_RESET"; }
info()  { printf '    %s\n' "$*"; }
ok()    { printf '%s  ✓ %s%s\n' "$C_GREEN" "$*" "$C_RESET"; }
warn()  { printf '%s  ! %s%s\n' "$C_YELLOW" "$*" "$C_RESET" >&2; }
fail()  { printf '%s  ✗ %s%s\n' "$C_RED" "$*" "$C_RESET" >&2; exit 1; }

# Fails unless every given command exists on PATH.
require() {
  local tool
  for tool in "$@"; do
    command -v "$tool" >/dev/null 2>&1 || fail "Required tool not found: $tool"
  done
}

# Runs a command from the repository root, echoing it first.
run() {
  info "\$ $*"
  "$@"
}

# Prints the package version from pubspec.yaml.
package_version() {
  sed -n 's/^version:[[:space:]]*//p' "$REPO_ROOT/pubspec.yaml" | head -n1 | tr -d '[:space:]'
}

# Prints the package name from pubspec.yaml.
package_name() {
  sed -n 's/^name:[[:space:]]*//p' "$REPO_ROOT/pubspec.yaml" | head -n1 | tr -d '[:space:]'
}

# Succeeds when $1 is a semantic version (MAJOR.MINOR.PATCH[-pre][+build]).
is_semver() {
  [[ "$1" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$ ]]
}

# Asks a yes/no question; succeeds only on an explicit "y" or "yes".
confirm() {
  local answer
  if [[ ! -t 0 ]]; then
    fail "Confirmation required but stdin is not a terminal: $1"
  fi
  read -r -p "$1 [y/N] " answer
  [[ "$answer" =~ ^([yY]|[yY][eE][sS])$ ]]
}

# Prints the versions of this package already published on pub.dev, one per
# line. Prints nothing when the package does not exist yet.
published_versions() {
  require curl
  local body
  body="$(curl -fsSL "https://pub.dev/api/packages/$(package_name)" 2>/dev/null || true)"
  [[ -z "$body" ]] && return 0
  printf '%s' "$body" | grep -o '"version":"[^"]*"' | sed 's/"version":"//; s/"$//' | sort -u
}

cd "$REPO_ROOT"

# Copies the files git would track (committed, plus untracked files that are
# not ignored by .gitignore or .git/info/exclude) into a new temporary
# directory and prints its path. Publishing from this copy guarantees that
# local-only files never reach pub.dev.
export_package_tree() {
  local dir
  dir="$(mktemp -d "${TMPDIR:-/tmp}/expandable_animation_publish.XXXXXX")"
  git -C "$REPO_ROOT" ls-files -z --cached --others --exclude-standard \
    | (cd "$REPO_ROOT" && tar --null -T - -cf -) \
    | tar -xf - -C "$dir"
  printf '%s\n' "$dir"
}
