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
readonly hid_event_readiness_diagnostic='Timed out while synthesizing event.'

udid=""
catalog=""
group_id=""
output=""
lock_owned=0
prepared_device=0
keyboard_snapshot=""
resume_from=""
audit_external_mutations=0

function usage() {
  print -u2 -- \
    "Usage: $0 [--lock-owned] [--prepared-device] --udid UDID " \
    "--catalog PATH --group-id ID --output PATH " \
    "[--keyboard-snapshot PATH] [--resume-from PATH] " \
    "[--audit-external-mutations]"
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
    --audit-external-mutations)
      audit_external_mutations=1
      shift
      ;;
    --udid|--catalog|--group-id|--output|--keyboard-snapshot|--resume-from)
      (( $# >= 2 )) || {
        usage
        exit 64
      }
      case "$1" in
        --udid) udid="$2" ;;
        --catalog) catalog="$2" ;;
        --group-id) group_id="$2" ;;
        --output) output="$2" ;;
        --keyboard-snapshot) keyboard_snapshot="$2" ;;
        --resume-from) resume_from="$2" ;;
      esac
      shift 2
      ;;
    *)
      usage
      exit 64
      ;;
  esac
done

[[ "$udid" == "$pinned_udid" && -f "$catalog" &&
   -n "$group_id" && -n "$output" ]] || {
  usage
  exit 64
}

if (( lock_owned == 0 )); then
  typeset -a lock_arguments
  lock_arguments=(
    --lock-owned --udid "$udid" --catalog "$catalog"
    --group-id "$group_id" --output "$output"
  )
  (( prepared_device == 0 )) || lock_arguments+=(--prepared-device)
  [[ -z "$keyboard_snapshot" ]] ||
    lock_arguments+=(--keyboard-snapshot "$keyboard_snapshot")
  [[ -z "$resume_from" ]] || lock_arguments+=(--resume-from "$resume_from")
  (( audit_external_mutations == 0 )) ||
    lock_arguments+=(--audit-external-mutations)
  exec Scripts/with-inputdec-simulator-test-lock.sh \
    --udid "$udid" -- \
    "$0" "${lock_arguments[@]}"
fi
[[ -n "${INPUTDEC_XCTEST_LOCK_OWNER_PID:-}" ]] || {
  print -u2 -- "Refusing group execution without the global XCTest lock"
  exit 75
}

catalog="${catalog:A}"
output="${output:A}"
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

xcodebuild_pid=""
patched_xctestrun=""
build_root=""
handshake=""

function stop_xcodebuild() {
  if [[ -n "$xcodebuild_pid" ]]; then
    kill "$xcodebuild_pid" 2>/dev/null || true
    wait "$xcodebuild_pid" 2>/dev/null || true
    xcodebuild_pid=""
  fi
}

function xcodebuild_is_live() {
  [[ -n "$xcodebuild_pid" ]] || return 1
  kill -0 "$xcodebuild_pid" 2>/dev/null || return 1
  local process_state
  process_state="$(ps -o state= -p "$xcodebuild_pid" 2>/dev/null)"
  process_state="${process_state//[[:space:]]/}"
  [[ -n "$process_state" && "$process_state" != Z* ]]
}

function scrub_secrets() {
  [[ -z "$patched_xctestrun" ]] || rm -f "$patched_xctestrun"
  patched_xctestrun=""
  rm -f "$staging"/**/boundary-*-response.json(N) \
    "$staging"/**/boundaries.json(N)
  [[ -z "$handshake" ]] || rm -rf "$handshake"
  handshake=""
}

function publish_failure() {
  local exit_code="$1"
  local message="$2"
  stop_xcodebuild
  scrub_secrets
  print -r -- "$message" >"$staging/failure.txt"
  mv "$staging" "$output"
  print -u2 -- "$message; evidence=$output"
  exit "$exit_code"
}

trap 'stop_xcodebuild; scrub_secrets' EXIT
trap 'stop_xcodebuild; scrub_secrets; exit 130' INT TERM

if ! python3 Scripts/text_input_batch.py show-group "$catalog" "$group_id" \
    >"$staging/selected-group.json"; then
  publish_failure 64 "Invalid catalog or group identifier"
fi

typeset -a group_fields
group_fields=("${(@f)$(python3 - "$staging/selected-group.json" <<'PY'
import json
import pathlib
import sys
group = json.loads(pathlib.Path(sys.argv[1]).read_text())
print(group["subsystem"])
for batch in group["batches"]:
    print(batch["id"])
PY
)}")
(( ${#group_fields[@]} == 2 || ${#group_fields[@]} == 5 )) ||
  publish_failure 65 "Logical group must contain one or four batches"
readonly subsystem="${group_fields[1]}"
typeset -a batch_ids
batch_ids=("${group_fields[@]:1}")
snapshot_group=0
if [[ "$group_id" == inline-prediction--snapshot-row-v1--* ]]; then
  snapshot_group=1
fi
if (( snapshot_group != 0 )); then
  (( prepared_device != 0 )) && [[ -d "$keyboard_snapshot" ]] ||
    publish_failure 64 \
      "Snapshot-row groups require a prepared device and keyboard snapshot"
  keyboard_snapshot="${keyboard_snapshot:A}"
  if [[ -n "$resume_from" ]]; then
    [[ -d "$resume_from" ]] ||
      publish_failure 64 "Snapshot resume source is missing"
    resume_from="${resume_from:A}"
  fi
elif (( prepared_device != 0 || audit_external_mutations != 0 )) ||
    [[ -n "$keyboard_snapshot" || -n "$resume_from" ]]; then
  publish_failure 64 "Snapshot arguments require a snapshot-row inline group"
fi
if ! python3 Scripts/text_input_group_protocol.py plan \
    --group "$staging/selected-group.json" >"$staging/boundary-plan.json"; then
  publish_failure 65 "Cannot construct group boundary plan"
fi
readonly boundary_count="$(python3 - "$staging/boundary-plan.json" <<'PY'
import json
import pathlib
import sys
print(len(json.loads(pathlib.Path(sys.argv[1]).read_text())))
PY
)"
(( boundary_count > 0 )) ||
  publish_failure 65 "Group boundary plan must not be empty"
case "$subsystem" in
  ime)
    readonly test_class="IDIMECompositionLifecycleUITests"
    default_request_timeout=90
    ;;
  autocorrection)
    readonly test_class="IDAutocorrectionDecisionUITests"
    default_request_timeout=180
    ;;
  inline-prediction)
    readonly test_class="IDInlinePredictionLifecycleUITests"
    default_request_timeout=180
    ;;
  *) publish_failure 64 "Unsupported group subsystem: $subsystem" ;;
esac
readonly default_request_timeout

source_xctestrun="${INPUTDEC_BATCH_XCTESTRUN:-}"
build_seconds=0
if [[ -z "$source_xctestrun" ]]; then
  build_started="$(date +%s)"
  build_root="${TMPDIR:-/tmp}/inputdec-group-build-$$"
  [[ ! -e "$build_root" ]] ||
    publish_failure 73 "Build path already exists: $build_root"
  if ! xcodebuild build-for-testing \
      -project InputDec.xcodeproj \
      -scheme InputDec \
      -destination "platform=iOS Simulator,id=${udid}" \
      -parallel-testing-enabled NO \
      -derivedDataPath "$build_root" \
      >"$staging/build.log" 2>&1; then
    publish_failure 65 "Group build-for-testing failed"
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
readonly total_started="$(date +%s)"

if (( snapshot_group != 0 )); then
  typeset -a snapshot_arguments
  snapshot_arguments=(
    --udid "$udid" --catalog "$catalog" --group-id "$group_id"
    --group "$staging/selected-group.json"
    --xctestrun "$source_xctestrun" --device-root "$device_root"
    --keyboard-snapshot "$keyboard_snapshot"
    --staging "$staging" --output "$output"
    --container-timeout "${INPUTDEC_GROUP_CONTAINER_TIMEOUT_SECONDS:-30}"
    --request-timeout "${INPUTDEC_GROUP_REQUEST_TIMEOUT_SECONDS:-180}"
  )
  [[ -z "$resume_from" ]] || snapshot_arguments+=(--resume-from "$resume_from")
  (( audit_external_mutations == 0 )) ||
    snapshot_arguments+=(--audit-external-mutations)
  if ! python3 Scripts/text_input_snapshot_group.py \
      "${snapshot_arguments[@]}"; then
    publish_failure 65 "Snapshot group execution failed"
  fi
  [[ -z "$build_root" || ! -d "$build_root" ]] || rm -rf "$build_root"
  trap - EXIT INT TERM
  print -r -- "PASS text-input snapshot group=$group_id output=$output"
  exit 0
fi

erase_boot_seconds=0
provisioning_reset_seconds=0
xctest_seconds=0
host_reset_seconds=0
row_reset_seconds=0
extraction_seconds=0
attempt=1
max_attempts=3
if [[ "$subsystem" == "inline-prediction" ]]; then
  max_attempts=20
fi
preserve_boot_retry=0
last_retained=""

while (( attempt <= max_attempts )); do
  attempt_directory="$staging/attempt-current"
  [[ ! -e "$attempt_directory" ]] ||
    publish_failure 73 "Attempt staging already exists"
  mkdir -p "$attempt_directory/boundaries"

  if (( preserve_boot_retry != 0 )); then
    [[ -d "$last_retained/provisioning" &&
       -d "$last_retained/learning-reset" ]] ||
      publish_failure 65 "Missing preserved-boot readiness provenance"
    xcrun simctl uninstall "$udid" \
      com.inputdec.demo.uitests.xctrunner 2>/dev/null || true
    cp -R "$last_retained/provisioning" \
      "$attempt_directory/provisioning"
    cp -R "$last_retained/learning-reset" \
      "$attempt_directory/learning-reset"
    phase_started="$(date +%s)"
    python3 Scripts/text_input_batch.py fingerprint \
      --udid "$udid" --device-root "$device_root" \
      --provisioning-summary "$attempt_directory/provisioning/summary.json" \
      --output "$attempt_directory/pre-state.json" >/dev/null
    provisioning_reset_seconds=$((
      provisioning_reset_seconds + $(date +%s) - phase_started
    ))
  else
    phase_started="$(date +%s)"
    xcrun simctl shutdown "$udid" 2>/dev/null || true
    xcrun simctl erase "$udid"
    xcrun simctl boot "$udid"
    xcrun simctl bootstatus "$udid" -b
    erase_boot_seconds=$((
      erase_boot_seconds + $(date +%s) - phase_started
    ))

    phase_started="$(date +%s)"
    xcrun simctl spawn "$udid" defaults write NSGlobalDomain AppleLocale en_US
    xcrun simctl spawn "$udid" defaults write NSGlobalDomain \
      AppleLanguages -array en-US
    Scripts/reset-text-input-learning.py \
      --udid "$udid" --device-root "$device_root" \
      --output "$attempt_directory/learning-reset"
    if [[ "$subsystem" == "ime" ]]; then
      Scripts/provision-ime-keyboards.sh \
        "$udid" "$attempt_directory/provisioning"
    else
      Scripts/provision-english-us-keyboard.sh \
        "$udid" "$attempt_directory/provisioning"
    fi
    python3 Scripts/text_input_batch.py fingerprint \
      --udid "$udid" --device-root "$device_root" \
      --provisioning-summary "$attempt_directory/provisioning/summary.json" \
      --output "$attempt_directory/pre-state.json" >/dev/null
    provisioning_reset_seconds=$((
      provisioning_reset_seconds + $(date +%s) - phase_started
    ))
  fi

  token="$(openssl rand -hex 32)"
  [[ ${#token} == 64 && "$token" != *[^0-9a-f]* ]] ||
    publish_failure 65 "Cannot generate group handshake token"
  patched_xctestrun="${source_xctestrun:h}/InputDec-group-$$-$attempt.xctestrun"
  [[ ! -e "$patched_xctestrun" ]] ||
    publish_failure 73 "Patched xctestrun already exists: $patched_xctestrun"
  cp "$source_xctestrun" "$patched_xctestrun"
  for variable in INPUTDEC_TEXT_INPUT_BATCH_ID \
      INPUTDEC_TEXT_INPUT_GROUP_ID INPUTDEC_TEXT_INPUT_GROUP_TOKEN; do
    /usr/libexec/PlistBuddy -c \
      "Delete :InputDecUITests:EnvironmentVariables:$variable" \
      "$patched_xctestrun" >/dev/null 2>&1 || true
  done
  /usr/libexec/PlistBuddy -c \
    "Add :InputDecUITests:EnvironmentVariables:INPUTDEC_TEXT_INPUT_GROUP_ID string $group_id" \
    "$patched_xctestrun"
  /usr/libexec/PlistBuddy -c \
    "Add :InputDecUITests:EnvironmentVariables:INPUTDEC_TEXT_INPUT_GROUP_TOKEN string $token" \
    "$patched_xctestrun"

  phase_started="$(date +%s)"
  xcodebuild test-without-building \
    -xctestrun "$patched_xctestrun" \
    -destination "platform=iOS Simulator,id=${udid}" \
    -parallel-testing-enabled NO \
    -maximum-concurrent-test-simulator-destinations 1 \
    -parallel-testing-worker-count 1 \
    -maximum-parallel-testing-workers 1 \
    -collect-test-diagnostics never \
    "-only-testing:InputDecUITests/${test_class}/testBatchedCertification" \
    -resultBundlePath "$attempt_directory/group.xcresult" \
    >"$attempt_directory/group.log" 2>&1 &
  xcodebuild_pid="$!"

  runner_container=""
  container_timeout="${INPUTDEC_GROUP_CONTAINER_TIMEOUT_SECONDS:-30}"
  request_timeout="${INPUTDEC_GROUP_REQUEST_TIMEOUT_SECONDS:-$default_request_timeout}"
  exit_grace="${INPUTDEC_GROUP_EXIT_GRACE_SECONDS:-1}"
  container_deadline=$(( $(date +%s) + container_timeout ))
  while [[ -z "$runner_container" && $(date +%s) -lt $container_deadline ]]; do
    runner_container="$(xcrun simctl get_app_container "$udid" \
      com.inputdec.demo.uitests.xctrunner data 2>/dev/null || true)"
    xcodebuild_is_live || break
    [[ -n "$runner_container" ]] || sleep 0.05
  done
  [[ -n "$runner_container" ]] || {
    stop_xcodebuild
    mv "$attempt_directory" "$staging/failed-attempt"
    publish_failure 65 "Cannot locate XCTest runner container"
  }
  handshake="$runner_container/Documents/InputDecTextInputGroup/$token"

  successful_boundaries=0
  boundary_failed=0
  for (( plan_offset = 1; plan_offset <= boundary_count; plan_offset++ )); do
    typeset -a boundary_fields
    boundary_fields=("${(@f)$(python3 - \
        "$staging/boundary-plan.json" "$plan_offset" <<'PY'
import json
import pathlib
import sys
identity = json.loads(pathlib.Path(sys.argv[1]).read_text())[int(sys.argv[2]) - 1]
print(identity["sequenceIndex"])
print(identity["kind"])
if identity["kind"] == "host":
    print(identity["batchId"])
    print(identity["rowId"])
    print(identity["completedHost"])
    print(identity["nextHost"])
elif identity["kind"] == "row":
    print(identity["batchId"])
    print(identity["completedRowId"])
    print(identity["nextRowId"])
else:
    print(identity["completedBatchId"])
    print(identity["nextBatchId"])
PY
    )}")
    index="${boundary_fields[1]}"
    kind="${boundary_fields[2]}"
    padded_index="$(printf '%03d' "$index")"
    request="$handshake/boundary-$padded_index-request.json"
    response="$handshake/boundary-$padded_index-response.json"
    request_deadline=$(( $(date +%s) + request_timeout ))
    while [[ ! -f "$request" && $(date +%s) -lt $request_deadline ]]; do
      xcodebuild_is_live || break
      sleep 0.05
    done
    if [[ ! -f "$request" ]]; then
      if xcodebuild_is_live; then
        exit_grace_deadline=$(( $(date +%s) + exit_grace ))
        while xcodebuild_is_live &&
            [[ $(date +%s) -lt $exit_grace_deadline ]]; do
          sleep 0.05
        done
        xcodebuild_is_live && boundary_failed=1
      fi
      break
    fi
    typeset -a protocol_arguments
    protocol_arguments=(
      --token "$token" --group-id "$group_id"
      --sequence-index "$index" --kind "$kind"
    )
    if [[ "$kind" == host ]]; then
      protocol_arguments+=(
        --batch-id "${boundary_fields[3]}"
        --row-id "${boundary_fields[4]}"
        --completed-host "${boundary_fields[5]}"
        --next-host "${boundary_fields[6]}"
      )
    elif [[ "$kind" == row ]]; then
      protocol_arguments+=(
        --batch-id "${boundary_fields[3]}"
        --completed-row-id "${boundary_fields[4]}"
        --next-row-id "${boundary_fields[5]}"
      )
    else
      protocol_arguments+=(
        --completed-batch-id "${boundary_fields[3]}"
        --next-batch-id "${boundary_fields[4]}"
      )
    fi
    if ! python3 Scripts/text_input_group_protocol.py validate-request \
        --path "$request" "${protocol_arguments[@]}" >/dev/null; then
      boundary_failed=1
      break
    fi
    reset_output="$attempt_directory/boundaries/"
    reset_output+="boundary-$padded_index-$kind-reset"
    reset_started="$(date +%s)"
    if ! python3 Scripts/text_input_live_boundary.py \
        --udid "$udid" --device-root "$device_root" \
        --output "$reset_output" >/dev/null; then
      boundary_failed=1
      break
    fi
    if [[ "$kind" == host ]]; then
      host_reset_seconds=$((
        host_reset_seconds + $(date +%s) - reset_started
      ))
    elif [[ "$kind" == row ]]; then
      row_reset_seconds=$((
        row_reset_seconds + $(date +%s) - reset_started
      ))
    fi
    reset_hash="$(shasum -a 256 "$reset_output/summary.json" | awk '{print $1}')"
    archived_response="$attempt_directory/"
    archived_response+="boundary-$padded_index-response.json"
    if ! python3 Scripts/text_input_group_protocol.py write-response \
        --path "$response" "${protocol_arguments[@]}" \
        --reset-summary-sha256 "$reset_hash" \
        >"$archived_response"; then
      boundary_failed=1
      break
    fi
    successful_boundaries=$plan_offset
  done

  if (( boundary_failed != 0 )) && xcodebuild_is_live; then
    kill "$xcodebuild_pid" 2>/dev/null || true
  fi
  set +e
  wait "$xcodebuild_pid"
  test_status="$?"
  set -e
  xcodebuild_pid=""
  xctest_seconds=$(( xctest_seconds + $(date +%s) - phase_started ))
  [[ -z "$handshake" ]] || rm -rf "$handshake"
  handshake=""
  rm -f "$patched_xctestrun"
  patched_xctestrun=""

  if (( test_status != 0 )); then
    prediction_readiness=0
    if rg -Fq -- "$prediction_readiness_diagnostic" \
        "$attempt_directory/group.log"; then
      prediction_readiness=1
    fi
    if (( attempt < max_attempts )) &&
       { (( prediction_readiness != 0 )) ||
         rg -q -- "$keyboard_readiness_diagnostic" \
           "$attempt_directory/group.log" ||
         rg -Fq -- "$hid_event_readiness_diagnostic" \
           "$attempt_directory/group.log" ||
         rg -Fq -- "$autocorrection_readiness_diagnostic" \
           "$attempt_directory/group.log"; }; then
      scrub_secrets
      retained="$staging/readiness-attempts/attempt-$attempt"
      mkdir -p "${retained:h}"
      if [[ -d "$attempt_directory/group.xcresult" ]]; then
        mv "$attempt_directory/group.xcresult" \
          "$attempt_directory/group.readiness-result"
      fi
      mv "$attempt_directory" "$retained"
      if [[ "$subsystem" == "inline-prediction" &&
            $prediction_readiness -ne 0 ]]; then
        preserve_boot_retry=1
        last_retained="$retained"
        print -r -- \
          "RETRY_PRESERVING_BOOT prediction-readiness group=$group_id attempt=$attempt"
      else
        preserve_boot_retry=0
        last_retained=""
        print -r -- \
          "RETRY keyboard-readiness group=$group_id attempt=$attempt"
      fi
      attempt=$(( attempt + 1 ))
      continue
    fi
    if (( boundary_failed != 0 )); then
      scrub_secrets
      mv "$attempt_directory" "$staging/failed-attempt"
      publish_failure 65 "Group boundary protocol failed"
    fi
    scrub_secrets
    mv "$attempt_directory" "$staging/failed-attempt"
    publish_failure 65 "Group XCTest failed"
  fi
  if (( boundary_failed != 0 )); then
    scrub_secrets
    mv "$attempt_directory" "$staging/failed-attempt"
    publish_failure 65 "Group boundary protocol failed"
  fi
  (( successful_boundaries == boundary_count )) || {
    scrub_secrets
    mv "$attempt_directory" "$staging/failed-attempt"
    publish_failure 65 "Group completed without its complete boundary plan"
  }

  phase_started="$(date +%s)"
  xcrun xcresulttool get test-results summary \
    --path "$attempt_directory/group.xcresult" --compact \
    >"$attempt_directory/xcresult-summary.json"
  Scripts/validate-autocorrection-summary.py \
    "$attempt_directory/xcresult-summary.json" \
    "$udid" "$expected_os_version" "$expected_os_build"
  xcrun xcresulttool export attachments \
    --path "$attempt_directory/group.xcresult" \
    --output-path "$attempt_directory/exported-attachments"
  python3 - "$attempt_directory/boundaries.json" \
      "$attempt_directory"/boundary-*-response.json <<'PY'
import json
import pathlib
import sys
path = pathlib.Path(sys.argv[1])
values = [json.loads(pathlib.Path(raw).read_text()) for raw in sys.argv[2:]]
path.write_text(json.dumps(values, indent=2, sort_keys=True) + "\n")
PY
  if ! python3 Scripts/text_input_batch.py extract-group \
      --catalog "$catalog" --group-id "$group_id" \
      --attachments "$attempt_directory/exported-attachments" \
      --xcresult "$attempt_directory/group.xcresult" \
      --boundaries "$attempt_directory/boundaries.json" \
      --output "$attempt_directory/materialized" >/dev/null; then
    scrub_secrets
    mv "$attempt_directory" "$staging/failed-attempt"
    publish_failure 65 "Group evidence extraction failed"
  fi
  rm -f "$attempt_directory"/boundary-*-response.json \
    "$attempt_directory/boundaries.json"
  python3 Scripts/text_input_batch.py fingerprint \
    --udid "$udid" --device-root "$device_root" \
    --provisioning-summary "$attempt_directory/provisioning/summary.json" \
    --output "$attempt_directory/post-state.json" >/dev/null
  mv "$attempt_directory/materialized"/* "$attempt_directory"/
  rmdir "$attempt_directory/materialized"
  extraction_seconds=$(( extraction_seconds + $(date +%s) - phase_started ))
  break
done

(( attempt <= max_attempts )) || publish_failure 65 "Readiness retries exhausted"

mv "$attempt_directory"/* "$staging"/
rmdir "$attempt_directory"
readonly total_seconds=$(( $(date +%s) - total_started ))
python3 - "$staging/group-timing.json" "$attempt" "$build_seconds" \
  "$erase_boot_seconds" "$provisioning_reset_seconds" \
  "$xctest_seconds" "$host_reset_seconds" "$row_reset_seconds" \
  "$extraction_seconds" \
  "$total_seconds" <<'PY'
import json
import pathlib
import sys
keys = [
    "attempts", "buildSeconds", "eraseBootSeconds",
    "provisioningResetSeconds", "xctestSeconds", "hostResetSeconds",
    "rowResetSeconds",
    "extractionComparisonSeconds", "totalSeconds",
]
values = [int(value) for value in sys.argv[2:]]
pathlib.Path(sys.argv[1]).write_text(json.dumps({
    "schema": 1,
    "xctestInvocations": 1,
    **dict(zip(keys, values)),
}, indent=2, sort_keys=True) + "\n")
PY

mv "$staging" "$output"
[[ -z "$build_root" || ! -d "$build_root" ]] || rm -rf "$build_root"
trap - EXIT INT TERM
print -r -- "PASS text-input group=$group_id attempts=$attempt output=$output"
