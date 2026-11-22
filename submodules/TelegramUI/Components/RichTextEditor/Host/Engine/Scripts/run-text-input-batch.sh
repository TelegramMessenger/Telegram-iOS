#!/bin/zsh

set -euo pipefail

readonly root="${0:A:h:h}"
cd "$root"

readonly pinned_udid="FA6F7462-AA97-42FE-9E57-8DA0593CE756"
readonly expected_os_version="26.5"
readonly expected_os_build="23F73"
readonly keyboard_readiness_diagnostic='Failed to determine hittability of "(k|n)" Key: Activation point invalid and no suggested hit points based on element frame'
readonly prediction_readiness_diagnostic='Expected native inline prediction was absent'
readonly autocorrection_readiness_diagnostic="Expected native candidate 'address' was not actionable"

udid=""
catalog=""
batch_id=""
output=""
lock_owned=0
prepared_device=0

function usage() {
  print -u2 -- \
    "Usage: $0 [--lock-owned] [--prepared-device] --udid UDID --catalog PATH " \
    "--batch-id ID --output PATH"
}

while (( $# > 0 )); do
  case "$1" in
    --lock-owned)
      lock_owned=1
      shift
      ;;
    --prepared-device)
      prepared_device=1
      shift
      ;;
    --udid|--catalog|--batch-id|--output)
      (( $# >= 2 )) || {
        usage
        exit 64
      }
      case "$1" in
        --udid) udid="$2" ;;
        --catalog) catalog="$2" ;;
        --batch-id) batch_id="$2" ;;
        --output) output="$2" ;;
      esac
      shift 2
      ;;
    *)
      usage
      exit 64
      ;;
  esac
done

[[ "$udid" == "$pinned_udid" ]] || {
  print -u2 -- "Refusing non-K3 simulator: $udid"
  exit 64
}
[[ -n "$catalog" && -n "$batch_id" && -n "$output" ]] || {
  usage
  exit 64
}
[[ -f "$catalog" ]] || {
  print -u2 -- "Missing batch catalog: $catalog"
  exit 64
}

if (( lock_owned == 0 )); then
  typeset -a prepared_argument
  prepared_argument=()
  (( prepared_device == 0 )) || prepared_argument=(--prepared-device)
  exec Scripts/with-inputdec-simulator-test-lock.sh \
    --udid "$udid" -- \
    "$0" --lock-owned "${prepared_argument[@]}" \
    --udid "$udid" --catalog "$catalog" \
    --batch-id "$batch_id" --output "$output"
fi
[[ -n "${INPUTDEC_XCTEST_LOCK_OWNER_PID:-}" ]] || {
  print -u2 -- "Refusing batch execution without the global XCTest lock"
  exit 75
}

output="${output:A}"
catalog="${catalog:A}"
[[ ! -e "$output" ]] || {
  print -u2 -- "Output path already exists: $output"
  exit 73
}
mkdir -p "${output:h}"
readonly staging="${output:h}/.${output:t}.partial-$$"
[[ ! -e "$staging" ]] || {
  print -u2 -- "Staging path already exists: $staging"
  exit 73
}
mkdir "$staging"

function publish_failure() {
  local exit_code="$1"
  local message="$2"
  print -r -- "$message" >"$staging/failure.txt"
  mv "$staging" "$output"
  print -u2 -- "$message; evidence=$output"
  exit "$exit_code"
}

if ! python3 Scripts/text_input_batch.py show "$catalog" "$batch_id" \
    >"$staging/selected-batch.json"; then
  publish_failure 64 "Invalid catalog or batch identifier"
fi
readonly subsystem="$(python3 - "$staging/selected-batch.json" <<'PY'
import json
import pathlib
import sys
print(json.loads(pathlib.Path(sys.argv[1]).read_text())["subsystem"])
PY
)"
case "$subsystem" in
  ime) readonly test_class="IDIMECompositionLifecycleUITests" ;;
  autocorrection) readonly test_class="IDAutocorrectionDecisionUITests" ;;
  inline-prediction)
    readonly test_class="IDInlinePredictionLifecycleUITests"
    ;;
  *) publish_failure 64 "Unsupported batch subsystem: $subsystem" ;;
esac

readonly total_started="$(date +%s)"
build_seconds=0
erase_boot_seconds=0
provisioning_reset_seconds=0
xctest_seconds=0
extraction_seconds=0
attempt=1

source_xctestrun="${INPUTDEC_BATCH_XCTESTRUN:-}"
build_root=""
if [[ -z "$source_xctestrun" ]]; then
  build_started="$(date +%s)"
  build_root="${TMPDIR:-/tmp}/inputdec-batch-build-$$"
  [[ ! -e "$build_root" ]] ||
    publish_failure 73 "Build path already exists: $build_root"
  if ! xcodebuild build-for-testing \
      -project InputDec.xcodeproj \
      -scheme InputDec \
      -destination "platform=iOS Simulator,id=${udid}" \
      -parallel-testing-enabled NO \
      -derivedDataPath "$build_root" \
      >"$staging/build.log" 2>&1; then
    publish_failure 65 "Batch build-for-testing failed"
  fi
  typeset -a xctestruns
  xctestruns=("$build_root"/Build/Products/*.xctestrun(N))
  (( ${#xctestruns[@]} == 1 )) ||
    publish_failure 65 "Expected exactly one built xctestrun"
  source_xctestrun="${xctestruns[1]}"
  build_seconds=$(( $(date +%s) - build_started ))
else
  source_xctestrun="${source_xctestrun:A}"
  [[ -f "$source_xctestrun" ]] ||
    publish_failure 64 "Missing prebuilt xctestrun: $source_xctestrun"
  print -r -- "$source_xctestrun" >"$staging/prebuilt-xctestrun.txt"
fi

readonly device_root="$HOME/Library/Developer/CoreSimulator/Devices/$udid/data"

while (( attempt <= 3 )); do
  attempt_directory="$staging/attempt-current"
  [[ ! -e "$attempt_directory" ]] ||
    publish_failure 73 "Attempt staging already exists"
  mkdir "$attempt_directory"

  if (( prepared_device == 0 )); then
    phase_started="$(date +%s)"
    xcrun simctl shutdown "$udid" 2>/dev/null || true
    xcrun simctl erase "$udid"
    xcrun simctl boot "$udid"
    xcrun simctl bootstatus "$udid" -b
    erase_boot_seconds=$(( erase_boot_seconds + $(date +%s) - phase_started ))
  else
    xcrun simctl bootstatus "$udid" -b
  fi

  phase_started="$(date +%s)"
  xcrun simctl spawn "$udid" defaults write NSGlobalDomain \
    AppleLocale en_US
  xcrun simctl spawn "$udid" defaults write NSGlobalDomain \
    AppleLanguages -array en-US
  Scripts/reset-text-input-learning.py \
    --udid "$udid" \
    --device-root "$device_root" \
    --output "$attempt_directory/learning-reset"
  Scripts/provision-ime-keyboards.sh \
    "$udid" "$attempt_directory/provisioning"
  xcrun simctl spawn "$udid" \
    launchctl kickstart -k user/501/com.apple.TextInput.kbd
  python3 Scripts/text_input_batch.py fingerprint \
    --udid "$udid" \
    --device-root "$device_root" \
    --provisioning-summary \
      "$attempt_directory/provisioning/summary.json" \
    --output "$attempt_directory/pre-state.json" >/dev/null
  provisioning_reset_seconds=$((
    provisioning_reset_seconds + $(date +%s) - phase_started
  ))

  patched_xctestrun="${source_xctestrun:h}/InputDec-batch-$$-$attempt.xctestrun"
  [[ ! -e "$patched_xctestrun" ]] ||
    publish_failure 73 "Patched xctestrun already exists: $patched_xctestrun"
  cp "$source_xctestrun" "$patched_xctestrun"
  /usr/libexec/PlistBuddy -c \
    'Delete :InputDecUITests:EnvironmentVariables:INPUTDEC_TEXT_INPUT_BATCH_ID' \
    "$patched_xctestrun" >/dev/null 2>&1 || true
  /usr/libexec/PlistBuddy -c \
    "Add :InputDecUITests:EnvironmentVariables:INPUTDEC_TEXT_INPUT_BATCH_ID string $batch_id" \
    "$patched_xctestrun"

  phase_started="$(date +%s)"
  set +e
  xcodebuild test-without-building \
    -xctestrun "$patched_xctestrun" \
    -destination "platform=iOS Simulator,id=${udid}" \
    -parallel-testing-enabled NO \
    -collect-test-diagnostics never \
    "-only-testing:InputDecUITests/${test_class}/testBatchedCertification" \
    -resultBundlePath "$attempt_directory/batch.xcresult" \
    >"$attempt_directory/batch.log" 2>&1
  test_status="$?"
  set -e
  xctest_seconds=$(( xctest_seconds + $(date +%s) - phase_started ))
  rm -f "$patched_xctestrun"

  if (( test_status != 0 )); then
    if (( attempt < 3 )) &&
       { rg -q -- "$keyboard_readiness_diagnostic" \
           "$attempt_directory/batch.log" ||
         rg -Fq -- "$prediction_readiness_diagnostic" \
           "$attempt_directory/batch.log" ||
         rg -Fq -- "$autocorrection_readiness_diagnostic" \
           "$attempt_directory/batch.log"; }; then
      retained="$staging/readiness-attempts/attempt-$attempt"
      mkdir -p "${retained:h}"
      mv "$attempt_directory" "$retained"
      xcrun simctl spawn "$udid" \
        launchctl kickstart -k user/501/com.apple.TextInput.kbd
      print -r -- "RETRY keyboard-readiness batch=$batch_id attempt=$attempt"
      attempt=$(( attempt + 1 ))
      continue
    fi
    mv "$attempt_directory" "$staging/failed-attempt"
    publish_failure 65 "Batch XCTest failed"
  fi

  phase_started="$(date +%s)"
  xcrun xcresulttool get test-results summary \
    --path "$attempt_directory/batch.xcresult" --compact \
    >"$attempt_directory/xcresult-summary.json"
  Scripts/validate-autocorrection-summary.py \
    "$attempt_directory/xcresult-summary.json" \
    "$udid" "$expected_os_version" "$expected_os_build"
  xcrun xcresulttool export attachments \
    --path "$attempt_directory/batch.xcresult" \
    --output-path "$attempt_directory/exported-attachments"
  python3 Scripts/text_input_batch.py extract \
    --catalog "$catalog" \
    --batch-id "$batch_id" \
    --attachments "$attempt_directory/exported-attachments" \
    --xcresult "$attempt_directory/batch.xcresult" \
    --output "$attempt_directory/materialized" >/dev/null
  python3 Scripts/text_input_batch.py fingerprint \
    --udid "$udid" \
    --device-root "$device_root" \
    --provisioning-summary \
      "$attempt_directory/provisioning/summary.json" \
    --output "$attempt_directory/post-state.json" >/dev/null
  mv "$attempt_directory/materialized"/* "$attempt_directory"/
  rmdir "$attempt_directory/materialized"
  extraction_seconds=$((
    extraction_seconds + $(date +%s) - phase_started
  ))
  break
done

(( attempt <= 3 )) || publish_failure 65 "Readiness retries exhausted"

mv "$attempt_directory"/* "$staging"/
rmdir "$attempt_directory"
readonly total_seconds=$(( $(date +%s) - total_started ))
python3 - "$staging/timing.json" "$attempt" "$build_seconds" \
  "$erase_boot_seconds" "$provisioning_reset_seconds" \
  "$xctest_seconds" "$extraction_seconds" "$total_seconds" <<'PY'
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
values = [int(value) for value in sys.argv[2:]]
keys = [
    "attempts", "buildSeconds", "eraseBootSeconds",
    "provisioningResetSeconds", "xctestSeconds",
    "extractionComparisonSeconds", "totalSeconds",
]
path.write_text(json.dumps({
    "schema": 1,
    **dict(zip(keys, values)),
}, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY

mv "$staging" "$output"
if [[ -n "$build_root" && -d "$build_root" ]]; then
  rm -rf "$build_root"
fi
print -r -- "PASS batch=$batch_id attempts=$attempt output=$output"
