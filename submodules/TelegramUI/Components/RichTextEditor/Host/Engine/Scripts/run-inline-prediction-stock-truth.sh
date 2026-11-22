#!/bin/zsh

set -euo pipefail

readonly root="${0:A:h:h}"
cd "${root}"

readonly simulator_id="${1:-FA6F7462-AA97-42FE-9E57-8DA0593CE756}"
readonly output_directory="${2:-.inline-prediction-task2-stock-truth-$(date +%Y%m%d-%H%M%S)}"
readonly expected_os_version="${3:-26.5}"
readonly expected_os_build="${4:-23F73}"

readonly -a rows=(
  'interior-accept|testStockInteriorAcceptTruth'
  'interior-dismiss-then-type|testStockInteriorDismissThenTypeTruth'
  'interior-accept-then-delete|testStockInteriorAcceptThenDeleteTruth'
  'before-boundary-accept|testStockBeforeBoundaryAcceptTruth'
  'before-boundary-dismiss-then-type|testStockBeforeBoundaryDismissThenTypeTruth'
  'before-boundary-accept-then-delete|testStockBeforeBoundaryAcceptThenDeleteTruth'
  'after-boundary-accept|testStockAfterBoundaryAcceptTruth'
  'after-boundary-dismiss-then-type|testStockAfterBoundaryDismissThenTypeTruth'
  'after-boundary-accept-then-delete|testStockAfterBoundaryAcceptThenDeleteTruth'
)

function require_no_overlapping_tests() {
  local overlap
  overlap="$(ps -axo pid=,command= |
    rg 'xcodebuild .*test|/xctest|XCTest' | rg -v 'rg ' || true)"
  if [[ -n "${overlap}" ]]; then
    print -r -- "${overlap}"
    print -u2 -- 'Refusing overlapping XCTest run'
    return 75
  fi
}

if [[ -e "${output_directory}" ]]; then
  print -u2 -- "Output path already exists: ${output_directory}"
  exit 73
fi

require_no_overlapping_tests
mkdir -p "${output_directory}"

for specification in "${rows[@]}"; do
  row="${specification%%|*}"
  method="${specification#*|}"
  result="${output_directory}/${row}.xcresult"
  summary="${output_directory}/${row}-summary.json"
  log="${output_directory}/${row}.log"

  require_no_overlapping_tests
  [[ ! -e "${result}" && ! -e "${summary}" && ! -e "${log}" ]] || {
    print -u2 -- "Refusing to replace preserved output for ${row}"
    exit 73
  }
  xcrun simctl shutdown "${simulator_id}" 2>/dev/null || true
  xcrun simctl erase "${simulator_id}"
  xcrun simctl boot "${simulator_id}"
  xcrun simctl bootstatus "${simulator_id}" -b
  require_no_overlapping_tests

  print -r -- "START ${row}"
  if ! xcodebuild test \
    -project InputDec.xcodeproj \
    -scheme InputDec \
    -destination "platform=iOS Simulator,id=${simulator_id}" \
    -parallel-testing-enabled NO \
    -collect-test-diagnostics never \
    "-only-testing:InputDecUITests/IDInlinePredictionLifecycleUITests/${method}" \
    -resultBundlePath "${result}" >"${log}" 2>&1; then
    tail -200 "${log}"
    exit 65
  fi
  xcrun xcresulttool get test-results summary \
    --path "${result}" --compact > "${summary}"
  Scripts/validate-autocorrection-summary.py \
    "${summary}" "${simulator_id}" \
    "${expected_os_version}" "${expected_os_build}"
  print -r -- "PASS ${row}"
done

print -r -- "Captured ${#rows[@]} isolated stock rows in ${output_directory}"
