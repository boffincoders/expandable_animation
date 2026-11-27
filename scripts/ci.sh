#!/usr/bin/env bash
# Local CI runner. GitHub Actions calls the same scripts, so a green local run
# means a green remote run (barring platform differences).
source "$(dirname "$0")/lib/common.sh"

usage() {
  cat <<USAGE
Usage: ./scripts/ci.sh [options]

With no options, runs the standard checks:
  setup, format, analyze, unit and widget tests, coverage, package validation.

Options:
  --all          Standard checks plus integration tests, goldens (macOS only),
                 the iOS Simulator and Android emulator runs (macOS only),
                 the web demo build and the documentation website build.
  --test         Format, analyze and unit/widget tests only.
  --coverage     Tests with coverage and the minimum coverage gate.
  --integration  Example integration tests (headless).
  --goldens      Golden tests (generated on macOS).
  --devices      Integration tests on an iOS Simulator and Android emulator.
  --web          Build the web demo.
  --docs         Build the documentation website (without the demo).
  --package      Package metadata validation and publish dry run.
  --no-setup     Skip toolchain checks and dependency installation.
  -h, --help     Show this help.

Options can be combined, for example: ./scripts/ci.sh --test --web
USAGE
}

S="$REPO_ROOT/scripts"
setup=true
selected=()
for arg in "$@"; do
  case "$arg" in
    --all) selected+=(format analyze coverage package integration goldens devices web docs) ;;
    --test) selected+=(format analyze test) ;;
    --coverage) selected+=(coverage) ;;
    --integration) selected+=(integration) ;;
    --goldens) selected+=(goldens) ;;
    --devices) selected+=(devices) ;;
    --web) selected+=(web) ;;
    --docs) selected+=(docs) ;;
    --package) selected+=(package) ;;
    --no-setup) setup=false ;;
    -h|--help) usage; exit 0 ;;
    *) usage; fail "Unknown option: $arg" ;;
  esac
done
if [[ ${#selected[@]} -eq 0 ]]; then
  selected=(format analyze coverage package)
fi

has() { local item; for item in "${selected[@]}"; do [[ "$item" == "$1" ]] && return 0; done; return 1; }

started=$(date +%s)
$setup && "$S/setup.sh"
has format && "$S/format.sh"
has analyze && "$S/analyze.sh"
if has coverage; then
  "$S/coverage.sh"
elif has test; then
  "$S/test.sh"
fi
if has goldens; then
  if [[ "$(uname -s)" == "Darwin" ]]; then
    step "Running golden tests"
    run flutter test --tags golden
  else
    warn "Skipping golden tests: goldens are generated on macOS"
  fi
fi
if has integration; then
  step "Running example integration tests"
  (cd "$EXAMPLE_DIR" && run flutter test integration_test -d flutter-tester)
fi
if has devices; then
  if [[ "$(uname -s)" == "Darwin" ]]; then
    "$S/test_devices.sh"
  else
    warn "Skipping simulator/emulator tests: the iOS Simulator needs macOS"
  fi
fi
has package && "$S/validate_package.sh"
has web && "$S/build_web.sh"
if has docs; then
  if has web; then
    "$S/build_docs.sh" --with-demo --skip-demo-build
  else
    "$S/build_docs.sh"
  fi
fi

printf '\n%sAll selected checks passed in %ss.%s\n' "$C_GREEN$C_BOLD" "$(( $(date +%s) - started ))" "$C_RESET"
