#!/usr/bin/env bash
# Runs unit, widget and (optionally) golden and integration tests.
source "$(dirname "$0")/lib/common.sh"

usage() {
  cat <<USAGE
Usage: ./scripts/test.sh [options]

  --goldens       Also run golden tests (tag: golden). Goldens are generated
                  on macOS; other platforms may differ by a few pixels.
  --integration   Also run the example app's integration tests (headless).
  -h, --help      Show this help.
USAGE
}

goldens=false
integration=false
for arg in "$@"; do
  case "$arg" in
    --goldens) goldens=true ;;
    --integration) integration=true ;;
    -h|--help) usage; exit 0 ;;
    *) fail "Unknown option: $arg" ;;
  esac
done

step "Running unit and widget tests"
run flutter test --exclude-tags golden
ok "Unit and widget tests passed"

if $goldens; then
  step "Running golden tests"
  run flutter test --tags golden
  ok "Golden tests passed"
fi

if $integration; then
  step "Running example integration tests"
  (cd "$EXAMPLE_DIR" && run flutter test integration_test -d flutter-tester)
  ok "Integration tests passed"
fi
