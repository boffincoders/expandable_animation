#!/usr/bin/env bash
# Verifies Dart formatting. Pass --fix to format files in place.
source "$(dirname "$0")/lib/common.sh"

case "${1:-}" in
  -h|--help)
    echo "Usage: ./scripts/format.sh [--fix]"
    echo "Without flags, fails when any file needs formatting."
    exit 0 ;;
  --fix)
    step "Formatting Dart code"
    run dart format lib test example/lib example/integration_test
    ok "Formatted" ;;
  "")
    step "Checking Dart formatting"
    run dart format --output=none --set-exit-if-changed lib test example/lib example/integration_test
    ok "Formatting is clean" ;;
  *) fail "Unknown option: $1" ;;
esac
