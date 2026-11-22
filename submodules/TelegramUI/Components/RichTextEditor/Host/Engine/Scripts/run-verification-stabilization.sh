#!/bin/zsh

set -euo pipefail

readonly root="${0:A:h:h}"
readonly pinned_udid="FA6F7462-AA97-42FE-9E57-8DA0593CE756"
udid=""
output=""
without_building=0

function usage() {
  print -u2 -- "Usage: $0 --udid UDID --output PATH [--without-building]"
}

while (( $# > 0 )); do
  case "$1" in
    --udid)
      (( $# >= 2 )) || { usage; exit 64; }
      udid="$2"
      shift 2
      ;;
    --output)
      (( $# >= 2 )) || { usage; exit 64; }
      output="$2"
      shift 2
      ;;
    --without-building)
      without_building=1
      shift
      ;;
    *)
      usage
      exit 64
      ;;
  esac
done

[[ "$udid" == "$pinned_udid" && -n "$output" ]] || {
  usage
  exit 64
}
output="${output:A}"

if [[ -z "${INPUTDEC_VERIFICATION_STABILIZATION_LOCKED:-}" ]]; then
  typeset -a forwarded
  forwarded=(--udid "$udid" --output "$output")
  (( without_building == 0 )) || forwarded+=(--without-building)
  exec "$root/Scripts/with-inputdec-simulator-test-lock.sh" \
    --udid "$udid" -- \
    env INPUTDEC_VERIFICATION_STABILIZATION_LOCKED=1 \
    "$0" "${forwarded[@]}"
fi

[[ ! -e "$output" ]] || {
  print -u2 -- "Refusing existing output: $output"
  exit 73
}
mkdir -p "$output"

if ! python3 Scripts/english_us_keyboard_profile.py verify \
    --udid "$udid" \
    --output "$output/english-us-profile" >/dev/null; then
  print -u2 -- "English-US profile is not ready. Provision it once with:"
  print -u2 -- \
    "Scripts/provision-english-us-keyboard.sh $udid <fresh-evidence-directory> --verify"
  exit 65
fi

typeset -a serialized_flags
serialized_flags=(
  -destination "platform=iOS Simulator,id=$udid"
  -parallel-testing-enabled NO
  -maximum-concurrent-test-simulator-destinations 1
  -parallel-testing-worker-count 1
  -maximum-parallel-testing-workers 1
)
readonly derived_data="${INPUTDEC_VERIFICATION_DERIVED_DATA_PATH:-$root/.verification-stabilization-derived-data}"

if (( without_building == 0 )); then
  xcodebuild build-for-testing \
    -project InputDec.xcodeproj -scheme InputDec \
    -derivedDataPath "$derived_data" \
    "${serialized_flags[@]}"
fi

function run_preflight() {
  local attempt="$1"
  local directory="$output/spelling-preflight-attempt-$attempt"
  local result="$directory/result.xcresult"
  local attachments="$directory/attachments"
  local metadata="$directory/result-metadata.json"
  local classification="$directory/classification.json"
  mkdir "$directory"

  set +e
  xcodebuild test-without-building \
    -project InputDec.xcodeproj -scheme InputDec \
    -derivedDataPath "$derived_data" \
    "${serialized_flags[@]}" \
    -collect-test-diagnostics never \
    -resultBundlePath "$result" \
    -only-testing:InputDecTests/IDSpellingReadinessProbeTests/testStockTextViewSpellingEnvironmentIsReady
  local test_status=$?
  set -e

  xcrun xcresulttool get test-results summary \
    --path "$result" --compact >"$metadata"
  xcrun xcresulttool export attachments \
    --path "$result" --output-path "$attachments"
  python3 Scripts/verification_stabilization.py classify-preflight \
    --xcresult "$metadata" \
    --attachments "$attachments" \
    --output "$classification"
  print -r -- "$classification"
  return 0
}

run_preflight 1
attempt_one="$output/spelling-preflight-attempt-1/classification.json"
classification="$(python3 -c \
  'import json,sys; print(json.load(open(sys.argv[1]))["classification"])' \
  "$attempt_one")"

family_metadata=""
family_status=0
if [[ "$classification" == ready ]]; then
  readonly family_directory="$output/spelling-family"
  readonly family_result="$family_directory/result.xcresult"
  family_metadata="$family_directory/result-metadata.json"
  mkdir "$family_directory"
  set +e
  xcodebuild test-without-building \
    -project InputDec.xcodeproj -scheme InputDec \
    -derivedDataPath "$derived_data" \
    "${serialized_flags[@]}" \
    -collect-test-diagnostics never \
    -resultBundlePath "$family_result" \
    -only-testing:InputDecTests/IDSpellingIntegrationTests \
    -only-testing:InputDecTests/IDBlockSpellingIntegrationTests/testMisspellingUsesNativeTemporaryPixelsAndCorrectionDropsBelowHalf \
    -only-testing:InputDecTests/IDTextLayoutCanvasParityTests/testSpellingMarkerPixelsAndRemovalMatchStockInTextRangeROI \
    -only-testing:InputDecTests/IDBlockTextViewParityTests/testNativeSpellingPixelCountsMatchStockInCanonicalWordROI
  family_status=$?
  set -e
  xcrun xcresulttool get test-results summary \
    --path "$family_result" --compact >"$family_metadata"
fi

summary_partial="$output/.summary.partial-$$"
typeset -a summary_arguments
summary_arguments=(
  write-summary
  --output "$summary_partial"
  --attempt-one "$attempt_one"
)
[[ -z "$family_metadata" ]] || \
  summary_arguments+=(--family-result "$family_metadata")
python3 Scripts/verification_stabilization.py "${summary_arguments[@]}"
mv "$summary_partial" "$output/summary.json"

final_classification="$(python3 -c \
  'import json,sys; print(json.load(open(sys.argv[1]))["classification"])' \
  "$output/summary.json")"
if [[ "$final_classification" == ready && $family_status -eq 0 ]]; then
  exit 0
fi
exit 65
