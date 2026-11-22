#!/bin/bash
# ==============================================================================================
# TASK PH4b — the underline measurement, re-run ONE ARM PER PROCESS.
#
# PH4 measured three arms in sequence inside a single host-app process and got a legacy reading
# (3 of 6 runs cleared the marker, bimodally) that it correctly declined to bill: legacy was always
# measured last, so order effects on the process-wide system checker were not excluded. That number
# decides whether the user's "corrected words are not underlined" defect is partly PRE-EXISTING in
# the shipping backend or wholly owned by the port.
#
# THE ISOLATION GUARANTEE, and how it is enforced rather than assumed:
#
#   1. Each row below is ONE `xcodebuild test-without-building -only-testing:<class>/<method>`
#      invocation. xcodebuild installs and launches the host app for the run and the process exits
#      when the bundle finishes, so a separate invocation is a separate host-app process. There is
#      no `-only-testing:` list and never more than one method per invocation.
#   2. The test itself checks it. `HostedUnderlineArmProbeCase.armsMeasuredInThisProcess` counts
#      arms actually driven; each method asserts it is 0 on entry and 1 on exit, so two arms sharing
#      a process is a loud failure and not a silent confound.
#   3. Every row prints its `pid=`. The summary at the end asserts that every pid is distinct. If
#      xcodebuild ever started reusing a process, that assertion is what would catch it.
#
# The arms are INTERLEAVED, not blocked: the sweep runs round after round of
# legacy / inputDec / stock rather than 20 legacy runs and then 10 of each control, and it rotates
# the order within each round. Simulator state that drifts over an hour — a warming text daemon,
# learned words, thermal state — would otherwise align with whichever arm was blocked into that
# stretch of wall clock, which is a different flavour of the exact confound this sweep removes.
#
#   ./Scripts/ph4b-isolation-sweep.sh            the standing sweep: 20 legacy, 10 stock, 10 inputDec
#   LEGACY_N=4 CONTROL_N=2 ./Scripts/ph4b-isolation-sweep.sh    a quick shakedown
#   LOG=/path/to/rows.txt ./Scripts/ph4b-isolation-sweep.sh     keep the raw rows somewhere else
#
# DEVICE defaults to iPhone 18 Pro **K1**, never K3 — K3 is reserved for certification runs that
# erase it, and for the project's logged-in Telegram install.
#
# WHY THESE SAMPLE SIZES: under "legacy has a real ~50% intermittent defect", the chance that n
# isolated runs all clear is 2^-n — 1/64 at PH4's n=6, which is why 6 settled nothing, and about
# 1 in a million at n=20. The controls are not being estimated (they had zero variance across PH4's
# 6 runs); they are being re-confirmed under isolation, and they are what proves a null legacy
# result is a measurement rather than a blind harness. Full reasoning in
# `Host/Tests/IDHostedIsolatedUnderlineArmTests.swift`.
# ==============================================================================================
set -uo pipefail
cd "$(dirname "$0")/.."

DEVICE="${DEVICE:-03A7DA9C-1832-49B8-9858-2F54F2FB5A04}"   # iPhone 18 Pro K1
DERIVED="Host/build"
SUITE="InputDecHostTests/IDHostedIsolatedUnderlineArmTests"
LEGACY_N="${LEGACY_N:-20}"
CONTROL_N="${CONTROL_N:-10}"
LOG="${LOG:-Host/build/ph4b-rows.txt}"

command -v xcodegen >/dev/null || { echo "xcodegen is not installed: brew install xcodegen" >&2; exit 1; }
xcodegen generate --spec Host/project.yml --project Host >/dev/null

DEST="platform=iOS Simulator,id=$DEVICE"
xcrun simctl boot "$DEVICE" 2>/dev/null || true
xcrun simctl bootstatus "$DEVICE" -b >/dev/null

# BUILD ONCE, then launch a process per row. `build-for-testing` + `test-without-building` is what
# keeps 40 process launches to minutes instead of an hour, and it does NOT weaken the isolation:
# the compiled bundle is shared, the PROCESS is not.
echo "==> build-for-testing"
xcodebuild build-for-testing -project Host/InputDecHost.xcodeproj -scheme InputDecHost \
  -destination "$DEST" -derivedDataPath "$DERIVED" \
  | grep -E "error:|\*\* (BUILD|TEST)" || true

XCTESTRUN=$(ls -t "$DERIVED"/Build/Products/*.xctestrun 2>/dev/null | head -1)
[ -n "$XCTESTRUN" ] || { echo "no .xctestrun produced — the build failed" >&2; exit 1; }
echo "==> xctestrun: $XCTESTRUN"

mkdir -p "$(dirname "$LOG")"
: > "$LOG"

run_one() {   # $1 = arm name, $2 = test method
  local arm="$1" method="$2" out
  out=$(xcodebuild test-without-building -xctestrun "$XCTESTRUN" -destination "$DEST" \
          -only-testing:"$SUITE/$method" \
          -parallel-testing-enabled NO -collect-test-diagnostics never 2>&1)
  local status=$?
  local row
  row=$(printf '%s\n' "$out" | grep -m1 '^PH4B-ROW ' || true)
  if [ -z "$row" ]; then
    echo "PH4B-ROW arm=$arm pid=NONE VOID=no-row-printed exit=$status" | tee -a "$LOG"
    printf '%s\n' "$out" | grep -E "error:|XCTAssert|failed" | head -8 >&2
    return
  fi
  if [ $status -ne 0 ]; then row="$row INVOCATION_FAILED=1"; fi
  echo "$row" | tee -a "$LOG"
}

echo "==> sweep: legacy x$LEGACY_N, stock x$CONTROL_N, inputDec x$CONTROL_N — interleaved"
ROUNDS=$LEGACY_N
[ "$CONTROL_N" -gt "$ROUNDS" ] && ROUNDS=$CONTROL_N
for ((r=0; r<ROUNDS; r++)); do
  # Rotate the within-round order so no arm is permanently first or last in a round either.
  case $((r % 3)) in
    0) order=(legacy stock inputDec) ;;
    1) order=(stock inputDec legacy) ;;
    2) order=(inputDec legacy stock) ;;
  esac
  for arm in "${order[@]}"; do
    case "$arm" in
      legacy)   [ $r -lt "$LEGACY_N" ]  && run_one legacy   test_isolatedArm_legacy ;;
      stock)    [ $r -lt "$CONTROL_N" ] && run_one stock    test_isolatedArm_stock ;;
      inputDec) [ $r -lt "$CONTROL_N" ] && run_one inputDec test_isolatedArm_inputDec ;;
    esac
  done
done

echo
echo "==> raw rows: $LOG"
./Scripts/ph4b-summarise.sh "$LOG"
