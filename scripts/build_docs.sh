#!/usr/bin/env bash
# Builds the documentation website (and optionally the web demo) into
# build/site, then validates every internal link.
source "$(dirname "$0")/lib/common.sh"

usage() {
  cat <<USAGE
Usage: ./scripts/build_docs.sh [--with-demo] [--skip-demo-build]

  --with-demo        Build the Flutter web demo and publish it at /demo/.
  --skip-demo-build  With --with-demo, reuse an existing example/build/web.
  -h, --help         Show this help.

Environment: SITE_URL (default $PAGES_URL)
USAGE
}

with_demo=false
build_demo=true
for arg in "$@"; do
  case "$arg" in
    --with-demo) with_demo=true ;;
    --skip-demo-build) build_demo=false ;;
    -h|--help) usage; exit 0 ;;
    *) fail "Unknown option: $arg" ;;
  esac
done

require python3
version="$(package_version)"
args=(--version "$version" --site-url "${SITE_URL:-$PAGES_URL}")

if $with_demo; then
  if $build_demo; then
    "$REPO_ROOT/scripts/build_web.sh"
  fi
  [[ -f "$EXAMPLE_DIR/build/web/index.html" ]] || fail "No web build found; run without --skip-demo-build"
  args+=(--demo "$EXAMPLE_DIR/build/web")
fi

step "Building the documentation website"
run python3 "$REPO_ROOT/scripts/build_site.py" "${args[@]}"
ok "Website ready in build/site"
