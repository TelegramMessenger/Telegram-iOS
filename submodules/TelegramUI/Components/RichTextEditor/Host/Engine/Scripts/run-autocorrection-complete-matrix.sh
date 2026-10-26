#!/bin/zsh
set -euo pipefail

root="${0:A:h:h}"
cd "$root"

simulator_udid="${1:-FA6F7462-AA97-42FE-9E57-8DA0593CE756}"
output_root="${2:-.autocorrection-task6-complete-matrix}"
expected_os_version="${3:-26.5}"
expected_os_build="${4:-23F73}"
methods=(
  InteriorAcceptSpace
  InteriorAcceptPunctuation
  InteriorAcceptCandidate
  InteriorRejectPrecommit
  InteriorUndoSpace
  InteriorUndoPunctuation
  InteriorUndoCandidate
  BeforeBoundaryAcceptSpace
  BeforeBoundaryAcceptPunctuation
  BeforeBoundaryAcceptCandidate
  BeforeBoundaryRejectPrecommit
  BeforeBoundaryUndoSpace
  BeforeBoundaryUndoPunctuation
  BeforeBoundaryUndoCandidate
  AfterBoundaryAcceptSpace
  AfterBoundaryAcceptPunctuation
  AfterBoundaryAcceptCandidate
  AfterBoundaryRejectPrecommit
  AfterBoundaryUndoSpace
  AfterBoundaryUndoPunctuation
  AfterBoundaryUndoCandidate
)

run_fresh_row() {
  local host="$1"
  local method="$2"
  local result="$3"
  local selector
  if [[ "$host" == Stock ]]; then
    selector="testStock${method}Truth"
  else
    selector="testCustom${method}MatchesStock"
  fi
  overlap="$(ps -axo pid=,command= | rg 'xcodebuild .*test|/xctest|XCTest' | rg -v 'rg ' || true)"
  if [[ -n "$overlap" ]]; then
    print -r -- "$overlap"
    echo 'Refusing overlapping XCTest run'
    exit 75
  fi
  if [[ -e "$result" ]]; then
    echo "Refusing to replace preserved result bundle: $result"
    exit 73
  fi
  xcrun simctl shutdown "$simulator_udid" 2>/dev/null || true
  xcrun simctl erase "$simulator_udid"
  xcrun simctl boot "$simulator_udid"
  xcrun simctl bootstatus "$simulator_udid" -b
  local log="${result%.xcresult}.log"
  echo "START host=$host method=$method result=$result"
  if ! xcodebuild test \
    -project InputDec.xcodeproj \
    -scheme InputDec \
    -destination "platform=iOS Simulator,id=$simulator_udid" \
    -parallel-testing-enabled NO \
    -collect-test-diagnostics never \
    -resultBundlePath "$result" \
    -only-testing:"InputDecUITests/IDAutocorrectionDecisionUITests/$selector" \
    >"$log" 2>&1; then
    tail -200 "$log"
    exit 65
  fi
  local summary="${result%.xcresult}-summary.json"
  xcrun xcresulttool get test-results summary \
    --path "$result" --compact > "$summary"
  Scripts/validate-autocorrection-summary.py \
    "$summary" "$simulator_udid" "$expected_os_version" "$expected_os_build"
  echo "PASS host=$host method=$method result=$result"
}

mkdir -p "$output_root"
for repetition in 1 2; do
  for order in StockThenCustom CustomThenStock; do
    for method in $methods; do
      pair="$output_root/repeat-${repetition}-${order}-${method}"
      if [[ -e "$pair" ]]; then
        echo "Refusing to replace preserved pair directory: $pair"
        exit 73
      fi
      mkdir -p "$pair"
      if [[ "$order" == StockThenCustom ]]; then
        hosts=(Stock Custom)
      else
        hosts=(Custom Stock)
      fi
      for host in $hosts; do
        run_fresh_row "$host" "$method" "$pair/${host:l}.xcresult"
      done
      if ! Scripts/compare-autocorrection-results.py \
        "$pair/stock.xcresult" "$pair/custom.xcresult" "$pair" \
        >"$pair/comparator.log" 2>&1; then
        cat "$pair/comparator.log"
        exit 65
      fi
      echo "PARITY repetition=$repetition order=$order method=$method"
    done
  done
done
