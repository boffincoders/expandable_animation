#!/usr/bin/env bash
# Runs static analysis for the package and the example app.
source "$(dirname "$0")/lib/common.sh"

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  echo "Usage: ./scripts/analyze.sh"
  exit 0
fi

step "Analyzing package"
run flutter analyze --fatal-infos --fatal-warnings
step "Analyzing example"
(cd "$EXAMPLE_DIR" && run flutter analyze --fatal-infos --fatal-warnings)
ok "No analyzer issues"
