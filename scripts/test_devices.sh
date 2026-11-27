#!/usr/bin/env bash
# Runs the example's integration tests on an iOS Simulator and an Android
# emulator. Starts one of each when none is running. Physical devices are
# never used.
source "$(dirname "$0")/lib/common.sh"

usage() {
  cat <<USAGE
Usage: ./scripts/test_devices.sh [--ios-only | --android-only]

Finds a running iOS Simulator and Android emulator (or starts one), then runs
example/integration_test on each and prints a per-platform summary. Fails if
a platform cannot be started or any test fails. macOS only for iOS.
USAGE
}

want_ios=true
want_android=true
case "${1:-}" in
  "") ;;
  --ios-only) want_android=false ;;
  --android-only) want_ios=false ;;
  -h|--help) usage; exit 0 ;;
  *) usage; fail "Unknown option: $1" ;;
esac

require flutter python3

# Prints the id of the first running emulator/simulator for a platform prefix.
running_device() {
  flutter devices --machine 2>/dev/null | python3 -c '
import json, sys
prefix = sys.argv[1]
for d in json.load(sys.stdin):
    if d.get("emulator") and d.get("targetPlatform", "").startswith(prefix):
        print(d["id"]); break
' "$1"
}

wait_for_device() {
  local prefix="$1" id="" tries=0
  while [[ -z "$id" && $tries -lt 60 ]]; do
    sleep 3
    id="$(running_device "$prefix")"
    tries=$((tries + 1))
  done
  printf '%s' "$id"
}

start_ios() {
  require xcrun
  local udid
  udid="$(xcrun simctl list devices available -j | python3 -c '
import json, sys
devices = json.load(sys.stdin)["devices"]
for runtime in sorted(devices, reverse=True):
    if "iOS" in runtime:
        for d in devices[runtime]:
            if "iPhone" in d["name"]:
                print(d["udid"]); sys.exit()
')"
  [[ -n "$udid" ]] || return 1
  info "Booting iOS Simulator $udid"
  xcrun simctl boot "$udid" >/dev/null 2>&1 || true
  open -a Simulator >/dev/null 2>&1 || true
}

start_android() {
  local avd
  avd="$(flutter emulators 2>/dev/null | awk -F' • ' '/ • android/ {gsub(/ /, "", $1); print $1; exit}')"
  [[ -n "$avd" ]] || return 1
  info "Launching Android emulator $avd"
  flutter emulators --launch "$avd" >/dev/null 2>&1 || true
}

# Android emulators sometimes lose their package manager after a system
# process crash ("Can't find service: package"); nothing can be installed
# until they restart. Reboot such an emulator and wait until it is usable.
ensure_android_healthy() {
  local id="$1" i
  command -v adb >/dev/null 2>&1 || return 0
  if adb -s "$id" shell service check package 2>/dev/null | grep -q ': found'; then
    return 0
  fi
  warn "Emulator $id has no package manager service; rebooting it"
  adb -s "$id" reboot >/dev/null 2>&1 || return 1
  adb -s "$id" wait-for-device
  for i in $(seq 1 100); do
    if [[ "$(adb -s "$id" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" == "1" ]] &&
      adb -s "$id" shell service check package 2>/dev/null | grep -q ': found'; then
      return 0
    fi
    sleep 3
  done
  return 1
}

results=()
status=0

run_on() {
  local label="$1" prefix="$2" starter="$3" id
  step "$label"
  id="$(running_device "$prefix")"
  if [[ -z "$id" ]]; then
    "$starter" || { warn "No $label available to start"; results+=("$label: unavailable"); status=1; return; }
    id="$(wait_for_device "$prefix")"
  fi
  if [[ -z "$id" ]]; then
    warn "$label did not start in time"
    results+=("$label: did not start")
    status=1
    return
  fi
  info "Using device $id"
  if [[ "$prefix" == android ]] && ! ensure_android_healthy "$id"; then
    warn "$label $id is not usable"
    results+=("$label ($id): unusable")
    status=1
    return
  fi
  local log code=0
  log="$(mktemp "${TMPDIR:-/tmp}/expandable_animation_devices.XXXXXX")"
  (cd "$EXAMPLE_DIR" && flutter test integration_test -d "$id") >"$log" 2>&1 || code=$?
  # Show the runner's final tally (progress lines are separated by \r).
  tr '\r' '\n' <"$log" | grep -aE 'All tests passed|Some tests failed' | tail -1 || true
  if [[ $code -eq 0 ]] && grep -aq 'All tests passed' "$log"; then
    results+=("$label ($id): passed")
    ok "$label passed"
    rm -f "$log"
  else
    results+=("$label ($id): FAILED (exit $code)")
    status=1
    warn "$label failed; full log: $log"
  fi
}

$want_ios && run_on "iOS Simulator" ios start_ios
$want_android && run_on "Android emulator" android start_android

step "Summary"
for line in "${results[@]}"; do info "$line"; done
[[ $status -eq 0 ]] || fail "Device tests did not all pass"
ok "Integration tests passed on every requested platform"
