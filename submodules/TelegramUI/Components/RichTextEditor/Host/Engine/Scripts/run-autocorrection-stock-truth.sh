#!/bin/zsh

set -euo pipefail

readonly simulator_id="${1:-FA6F7462-AA97-42FE-9E57-8DA0593CE756}"
readonly output_directory="${2:-.autocorrection-task1-stock-truth-$(date +%Y%m%d-%H%M%S)}"
readonly expected_os_version="${3:-26.5}"
readonly expected_os_build="${4:-23F73}"

readonly -a rows=(
  'interior-accept-space|testStockInteriorAcceptSpaceTruth'
  'interior-accept-punctuation|testStockInteriorAcceptPunctuationTruth'
  'interior-accept-candidate|testStockInteriorAcceptCandidateTruth'
  'interior-reject-precommit|testStockInteriorRejectPrecommitTruth'
  'interior-undo-space|testStockInteriorUndoSpaceTruth'
  'interior-undo-punctuation|testStockInteriorUndoPunctuationTruth'
  'interior-undo-candidate|testStockInteriorUndoCandidateTruth'
  'before-boundary-accept-space|testStockBeforeBoundaryAcceptSpaceTruth'
  'before-boundary-accept-punctuation|testStockBeforeBoundaryAcceptPunctuationTruth'
  'before-boundary-accept-candidate|testStockBeforeBoundaryAcceptCandidateTruth'
  'before-boundary-reject-precommit|testStockBeforeBoundaryRejectPrecommitTruth'
  'before-boundary-undo-space|testStockBeforeBoundaryUndoSpaceTruth'
  'before-boundary-undo-punctuation|testStockBeforeBoundaryUndoPunctuationTruth'
  'before-boundary-undo-candidate|testStockBeforeBoundaryUndoCandidateTruth'
  'after-boundary-accept-space|testStockAfterBoundaryAcceptSpaceTruth'
  'after-boundary-accept-punctuation|testStockAfterBoundaryAcceptPunctuationTruth'
  'after-boundary-accept-candidate|testStockAfterBoundaryAcceptCandidateTruth'
  'after-boundary-reject-precommit|testStockAfterBoundaryRejectPrecommitTruth'
  'after-boundary-undo-space|testStockAfterBoundaryUndoSpaceTruth'
  'after-boundary-undo-punctuation|testStockAfterBoundaryUndoPunctuationTruth'
  'after-boundary-undo-candidate|testStockAfterBoundaryUndoCandidateTruth'
)

function require_no_overlapping_tests() {
  local overlap
  overlap="$(ps -axo pid=,command= | rg 'xcodebuild .*test|/xctest|XCTest' | rg -v 'rg ' || true)"
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

mkdir -p "${output_directory}"

for specification in "${rows[@]}"; do
  row="${specification%%|*}"
  method="${specification#*|}"
  result="${output_directory}/${row}.xcresult"
  warmup_result="${output_directory}/${row}-warmup.xcresult"

  require_no_overlapping_tests
  xcrun simctl shutdown "${simulator_id}" 2>/dev/null || true
  xcrun simctl erase "${simulator_id}"
  xcrun simctl boot "${simulator_id}"
  xcrun simctl bootstatus "${simulator_id}" -b
  require_no_overlapping_tests

  xcodebuild test \
    -project InputDec.xcodeproj \
    -scheme InputDec \
    -destination "platform=iOS Simulator,id=${simulator_id}" \
    -parallel-testing-enabled NO \
    -collect-test-diagnostics never \
    -only-testing:InputDecUITests/IDAutocorrectionDecisionUITests/testStockKeyboardWarmupOnly \
    -resultBundlePath "${warmup_result}"
  xcrun xcresulttool get test-results summary \
    --path "${warmup_result}" --compact \
    > "${output_directory}/${row}-warmup-summary.json"
  Scripts/validate-autocorrection-summary.py \
    "${output_directory}/${row}-warmup-summary.json" \
    "${simulator_id}" "${expected_os_version}" "${expected_os_build}"

  require_no_overlapping_tests

  xcodebuild test \
    -project InputDec.xcodeproj \
    -scheme InputDec \
    -destination "platform=iOS Simulator,id=${simulator_id}" \
    -parallel-testing-enabled NO \
    -collect-test-diagnostics never \
    "-only-testing:InputDecUITests/IDAutocorrectionDecisionUITests/${method}" \
    -resultBundlePath "${result}"

  xcrun xcresulttool get test-results summary \
    --path "${result}" --compact \
    > "${output_directory}/${row}-summary.json"
  Scripts/validate-autocorrection-summary.py \
    "${output_directory}/${row}-summary.json" \
    "${simulator_id}" "${expected_os_version}" "${expected_os_build}"
done

print -r -- "Captured ${#rows[@]} isolated stock rows in ${output_directory}"
