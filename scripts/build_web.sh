#!/usr/bin/env bash
# Builds the example app for the web with the GitHub Pages base path.
source "$(dirname "$0")/lib/common.sh"

BASE_HREF="${BASE_HREF:-${PAGES_BASE_PATH}demo/}"

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  echo "Usage: BASE_HREF=/expandable_animation/demo/ ./scripts/build_web.sh"
  echo "Output: example/build/web"
  exit 0
fi

step "Building the web demo (base href $BASE_HREF)"
(cd "$EXAMPLE_DIR" && run flutter build web --release --base-href "$BASE_HREF")
ok "Web demo built in example/build/web"
