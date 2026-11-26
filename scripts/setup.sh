#!/usr/bin/env bash
# Validates the toolchain and installs dependencies for the package and the
# example app.
source "$(dirname "$0")/lib/common.sh"

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  echo "Usage: ./scripts/setup.sh"
  echo "Checks for Flutter and Dart and runs 'flutter pub get' for the package and example."
  exit 0
fi

step "Checking toolchain"
require flutter dart git
run flutter --version
ok "Flutter and Dart available"

step "Installing dependencies"
run flutter pub get
(cd "$EXAMPLE_DIR" && run flutter pub get)
ok "Dependencies installed"
