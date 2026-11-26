#!/usr/bin/env bash
# Runs the test suite with coverage and enforces a minimum line coverage.
source "$(dirname "$0")/lib/common.sh"

MIN_COVERAGE="${MIN_COVERAGE:-90}"

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  echo "Usage: MIN_COVERAGE=90 ./scripts/coverage.sh"
  echo "Writes coverage/lcov.info and fails below MIN_COVERAGE percent (default 90)."
  exit 0
fi

step "Running tests with coverage"
run flutter test --coverage --exclude-tags golden

step "Checking coverage of lib/"
summary="$(awk -F'[:,]' '
  /^SF:/ { inlib = ($2 ~ /lib\//) }
  /^DA:/ && inlib { total++; if ($3 > 0) hit++ }
  END { if (total == 0) { print "0 0 0" } else { printf "%d %d %.1f\n", hit, total, hit * 100 / total } }
' coverage/lcov.info)"
read -r hit total percent <<<"$summary"
info "Covered $hit of $total lines ($percent%)"
awk -v p="$percent" -v m="$MIN_COVERAGE" 'BEGIN { exit !(p + 0 >= m + 0) }' \
  || fail "Coverage $percent% is below the required $MIN_COVERAGE%"
ok "Coverage $percent% meets the $MIN_COVERAGE% minimum"
