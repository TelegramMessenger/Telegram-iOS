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
output=""
lock_owned=0
without_building=0
derived_data_path=""

function usage() {
  print -u2 -- \
    "Usage: $0 --udid UDID --output PATH [--without-building --derived-data-path PATH]"
}

while (( $# > 0 )); do
  case "$1" in
    --udid|--output|--derived-data-path)
      (( $# >= 2 )) || {
        usage
        exit 64
      }
      case "$1" in
        --udid) udid="$2" ;;
        --output) output="$2" ;;
        --derived-data-path) derived_data_path="$2" ;;
      esac
      shift 2
      ;;
    --lock-owned)
      lock_owned=1
      shift
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

[[ "$udid" == "$pinned_udid" ]] || {
  print -u2 -- "Refusing non-K3 simulator: $udid"
  exit 64
}
[[ -n "$output" ]] || {
  usage
  exit 64
}
if (( without_building == 1 )) && [[ -z "$derived_data_path" ]]; then
  print -u2 -- "--without-building requires --derived-data-path PATH"
  exit 64
fi

if (( lock_owned == 0 )); then
  forwarded=(--lock-owned --udid "$udid" --output "$output")
  (( without_building == 0 )) || forwarded+=(--without-building)
  [[ -z "$derived_data_path" ]] || forwarded+=(
    --derived-data-path "$derived_data_path"
  )
  exec Scripts/with-inputdec-simulator-test-lock.sh \
    --udid "$udid" -- \
    "$0" "${forwarded[@]}"
fi
[[ -n "${INPUTDEC_XCTEST_LOCK_OWNER_PID:-}" ]] || {
  print -u2 -- "Refusing sentinel execution without the global XCTest lock"
  exit 75
}
[[ ! -e "$output" ]] || {
  print -u2 -- "Output path already exists: $output"
  exit 73
}

mkdir -p "$output"
readonly started_at="$(date +%s)"

# The existing provisioner normalizes the complete iOS 26.5 input-mode
# inventory, performs the suite's sole shutdown/boot cycle, and leaves the
# fixed English fallback active for the first method.
if [[ "${INPUTDEC_KEYBOARD_SENTINEL_COMMAND_TESTING:-0}" != 1 ]]; then
  xcrun simctl boot "$udid" 2>/dev/null || true
  xcrun simctl bootstatus "$udid" -b
  Scripts/reset-text-input-learning.py \
    --udid "$udid" \
    --device-root "$HOME/Library/Developer/CoreSimulator/Devices/$udid/data" \
    --output "$output/learning-reset"
  Scripts/provision-ime-keyboards.sh "$udid" "$output/provisioning"
fi

function write_method_summary() {
  local raw_summary="$1"
  local summary="$2"
  local group="$3"
  local method="$4"
  python3 - "$raw_summary" "$summary" "$group" "$method" \
    "$udid" "$expected_os_version" "$expected_os_build" <<'PY'
import json
import pathlib
import sys

(
    raw_path,
    summary_path,
    group,
    method,
    expected_udid,
    expected_version,
    expected_build,
) = sys.argv[1:]
source = json.loads(pathlib.Path(raw_path).read_text(encoding="utf-8"))
configurations = source.get("devicesAndConfigurations")
if not isinstance(configurations, list) or len(configurations) != 1:
    raise SystemExit(f"{group}/{method}: expected one device configuration")
configuration = configurations[0]
device = configuration.get("device")
if not isinstance(device, dict):
    raise SystemExit(f"{group}/{method}: missing device metadata")
expected_device = {
    "deviceId": expected_udid,
    "osVersion": expected_version,
    "osBuildNumber": expected_build,
}
for key, expected in expected_device.items():
    if device.get(key) != expected:
        raise SystemExit(
            f"{group}/{method}: {key} expected {expected!r}, "
            f"found {device.get(key)!r}"
        )
for container, label in ((source, "summary"), (configuration, "device")):
    expected = {
        "passedTests": 1,
        "failedTests": 0,
        "skippedTests": 0,
        "expectedFailures": 0,
    }
    for key, value in expected.items():
        if type(container.get(key)) is not int or container.get(key) != value:
            raise SystemExit(
                f"{group}/{method}: {label}.{key} expected {value}, "
                f"found {container.get(key)!r}"
            )
if source.get("result") != "Passed":
    raise SystemExit(
        f"{group}/{method}: result expected 'Passed', "
        f"found {source.get('result')!r}"
    )
if source.get("totalTestCount") != 1:
    raise SystemExit(
        f"{group}/{method}: expected 1 test, "
        f"found {source.get('totalTestCount')!r}"
    )
start = source.get("startTime")
finish = source.get("finishTime")
if not isinstance(start, (int, float)) or not isinstance(
    finish, (int, float)
):
    raise SystemExit(f"{group}/{method}: missing XCTest timestamps")
summary = {
    "schema": 1,
    "group": group,
    "method": method,
    "result": source["result"],
    "passedTests": source["passedTests"],
    "failedTests": source["failedTests"],
    "skippedTests": source["skippedTests"],
    "startTime": start,
    "finishTime": finish,
    "testDurationSeconds": finish - start,
    "device": expected_device,
}
pathlib.Path(summary_path).write_text(
    json.dumps(summary, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
PY
}

function run_method() {
  local group="$1"
  local method="$2"
  local result_relative="$3"
  local selector="$4"
  local result="$output/$result_relative"
  local method_directory="${result:h}"
  local summary="$method_directory/summary.json"
  local raw_summary="$method_directory/xcresult-summary.json"
  local log="$method_directory/xcodebuild.log"
  local attempt=1

  mkdir -p "$method_directory"
  while true; do
    local -a command
    local action="test"
    (( without_building == 0 )) || action="test-without-building"
    command=(
      xcodebuild "$action"
      -project InputDec.xcodeproj
      -scheme InputDec
      -destination "platform=iOS Simulator,id=${udid}"
      -parallel-testing-enabled NO
      -collect-test-diagnostics never
      -resultBundlePath "$result"
      "-only-testing:${selector}"
    )
    [[ -z "$derived_data_path" ]] || command+=(
      -derivedDataPath "$derived_data_path"
    )

    print -r -- \
      "START group=$group method=$method attempt=$attempt result=$result"
    if "${command[@]}" >"$log" 2>&1; then
      break
    fi

    if (( attempt < 3 )) &&
       { rg -q -- "$keyboard_readiness_diagnostic" "$log" ||
         rg -Fq -- "$prediction_readiness_diagnostic" "$log" ||
         rg -Fq -- "$autocorrection_readiness_diagnostic" "$log"; }; then
      local retained="$method_directory/readiness-attempts/attempt-$attempt"
      mkdir -p "$retained"
      [[ -e "$result" ]] && mv "$result" "$retained/"
      mv "$log" "$retained/"
      xcrun simctl spawn "$udid" \
        launchctl kickstart -k user/501/com.apple.TextInput.kbd
      print -r -- \
        "RETRY keyboard-readiness group=$group method=$method attempt=$attempt"
      attempt=$((attempt + 1))
      continue
    fi

    tail -200 "$log"
    return 65
  done

  xcrun xcresulttool get test-results summary \
    --path "$result" --compact >"$raw_summary"
  write_method_summary "$raw_summary" "$summary" "$group" "$method"
  print -r -- "PASS group=$group method=$method tests=1 result=$result"
}

run_method \
  english autocorrection-accept-space \
  "english/autocorrection-accept-space/autocorrection-accept-space.xcresult" \
  "InputDecUITests/IDAutocorrectionDecisionUITests/testCustomInteriorAcceptSpaceMatchesStock"

run_method \
  english autocorrection-accept-space-minimal \
  "english/autocorrection-accept-space-minimal/autocorrection-accept-space-minimal.xcresult" \
  "InputDecUITests/IDAutocorrectionDecisionUITests/testMinimalInteriorAcceptSpaceMatchesStock"

run_method \
  english autocorrection-reject-before-boundary \
  "english/autocorrection-reject-before-boundary/autocorrection-reject-before-boundary.xcresult" \
  "InputDecUITests/IDAutocorrectionDecisionUITests/testCustomBeforeBoundaryRejectPrecommitMatchesStock"

run_method \
  english autocorrection-reject-before-boundary-minimal \
  "english/autocorrection-reject-before-boundary-minimal/autocorrection-reject-before-boundary-minimal.xcresult" \
  "InputDecUITests/IDAutocorrectionDecisionUITests/testMinimalBeforeBoundaryRejectPrecommitMatchesStock"

run_method \
  english inline-accept \
  "english/inline-accept/inline-accept.xcresult" \
  "InputDecUITests/IDInlinePredictionLifecycleUITests/testCustomInteriorAcceptMatchesStock"

run_method \
  english inline-accept-minimal \
  "english/inline-accept-minimal/inline-accept-minimal.xcresult" \
  "InputDecUITests/IDInlinePredictionLifecycleUITests/testMinimalInteriorAcceptMatchesStock"

run_method \
  english inline-dismiss-before-boundary \
  "english/inline-dismiss-before-boundary/inline-dismiss-before-boundary.xcresult" \
  "InputDecUITests/IDInlinePredictionLifecycleUITests/testCustomBeforeBoundaryDismissThenTypeMatchesStock"

run_method \
  english inline-dismiss-before-boundary-minimal \
  "english/inline-dismiss-before-boundary-minimal/inline-dismiss-before-boundary-minimal.xcresult" \
  "InputDecUITests/IDInlinePredictionLifecycleUITests/testMinimalBeforeBoundaryDismissThenTypeMatchesStock"

run_method \
  english floating-normal \
  "english/floating-normal/floating-normal.xcresult" \
  "InputDecUITests/IDFloatingCursorUITests/testFloatingCursorNormalEndMatchesStockAndQuiesces"

run_method \
  english floating-normal-minimal \
  "english/floating-normal-minimal/floating-normal-minimal.xcresult" \
  "InputDecUITests/IDFloatingCursorUITests/testMinimalFloatingCursorNormalEndMatchesStockAndQuiesces"

run_method \
  english floating-selection-extension \
  "english/floating-selection-extension/floating-selection-extension.xcresult" \
  "InputDecUITests/IDFloatingCursorUITests/testFloatingCursorSelectionExtensionKeepsInitialLogicalAnchor"

run_method \
  english floating-selection-extension-minimal \
  "english/floating-selection-extension-minimal/floating-selection-extension-minimal.xcresult" \
  "InputDecUITests/IDFloatingCursorUITests/testMinimalFloatingCursorSelectionExtensionKeepsInitialLogicalAnchor"

run_method \
  english inline-formatting-bold \
  "english/inline-formatting-bold/inline-formatting-bold.xcresult" \
  "InputDecUITests/IDInlineFormattingKeyboardUITests/testRealKeyboardBoldTypingMatchesStock"

run_method \
  english inline-formatting-bold-minimal \
  "english/inline-formatting-bold-minimal/inline-formatting-bold-minimal.xcresult" \
  "InputDecUITests/IDInlineFormattingKeyboardUITests/testMinimalRealKeyboardBoldTypingMatchesStock"

run_method \
  english inline-formatting-autocorrection \
  "english/inline-formatting-autocorrection/inline-formatting-autocorrection.xcresult" \
  "InputDecUITests/IDInlineFormattingKeyboardUITests/testRealKeyboardAutocorrectionPreservesBoldMatchesStock"

run_method \
  english inline-formatting-autocorrection-minimal \
  "english/inline-formatting-autocorrection-minimal/inline-formatting-autocorrection-minimal.xcresult" \
  "InputDecUITests/IDInlineFormattingKeyboardUITests/testMinimalRealKeyboardAutocorrectionPreservesBoldMatchesStock"

run_method \
  english inline-formatting-prediction \
  "english/inline-formatting-prediction/inline-formatting-prediction.xcresult" \
  "InputDecUITests/IDInlineFormattingKeyboardUITests/testRealKeyboardPredictionAcceptAndRejectDoNotLeakTraits"

run_method \
  english inline-formatting-prediction-minimal \
  "english/inline-formatting-prediction-minimal/inline-formatting-prediction-minimal.xcresult" \
  "InputDecUITests/IDInlineFormattingKeyboardUITests/testMinimalRealKeyboardPredictionAcceptAndRejectDoNotLeakTraits"

run_method \
  english inline-formatting-marked-text \
  "english/inline-formatting-marked-text/inline-formatting-marked-text.xcresult" \
  "InputDecUITests/IDInlineFormattingKeyboardUITests/testRealKeyboardMarkedTextCommitPreservesActiveTraits"

run_method \
  english inline-formatting-marked-text-minimal \
  "english/inline-formatting-marked-text-minimal/inline-formatting-marked-text-minimal.xcresult" \
  "InputDecUITests/IDInlineFormattingKeyboardUITests/testMinimalRealKeyboardMarkedTextCommitPreservesActiveTraits"

run_method \
  japanese ime-return-commit-undo \
  "japanese/ime-return-commit-undo/ime-return-commit-undo.xcresult" \
  "InputDecUITests/IDIMECompositionLifecycleUITests/testCustomJapaneseBeforeBoundaryReturnCommitThenUndoTruth"

run_method \
  japanese ime-return-commit-undo-minimal \
  "japanese/ime-return-commit-undo-minimal/ime-return-commit-undo-minimal.xcresult" \
  "InputDecUITests/IDIMECompositionLifecycleUITests/testMinimalJapaneseBeforeBoundaryReturnCommitThenUndoTruth"

run_method \
  chinese ime-candidate-commit \
  "chinese/ime-candidate-commit/ime-candidate-commit.xcresult" \
  "InputDecUITests/IDIMECompositionLifecycleUITests/testCustomSimplifiedChinesePinyinInteriorCandidateCommitTruth"

run_method \
  chinese ime-candidate-commit-minimal \
  "chinese/ime-candidate-commit-minimal/ime-candidate-commit-minimal.xcresult" \
  "InputDecUITests/IDIMECompositionLifecycleUITests/testMinimalSimplifiedChinesePinyinInteriorCandidateCommitTruth"

readonly finished_at="$(date +%s)"
python3 - "$output" "$started_at" "$finished_at" "$udid" <<'PY'
import json
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
started_at = int(sys.argv[2])
finished_at = int(sys.argv[3])
udid = sys.argv[4]
method_contract = (
    ("english", "autocorrection-accept-space"),
    ("english", "autocorrection-accept-space-minimal"),
    ("english", "autocorrection-reject-before-boundary"),
    ("english", "autocorrection-reject-before-boundary-minimal"),
    ("english", "inline-accept"),
    ("english", "inline-accept-minimal"),
    ("english", "inline-dismiss-before-boundary"),
    ("english", "inline-dismiss-before-boundary-minimal"),
    ("english", "floating-normal"),
    ("english", "floating-normal-minimal"),
    ("english", "floating-selection-extension"),
    ("english", "floating-selection-extension-minimal"),
    ("english", "inline-formatting-bold"),
    ("english", "inline-formatting-bold-minimal"),
    ("english", "inline-formatting-autocorrection"),
    ("english", "inline-formatting-autocorrection-minimal"),
    ("english", "inline-formatting-prediction"),
    ("english", "inline-formatting-prediction-minimal"),
    ("english", "inline-formatting-marked-text"),
    ("english", "inline-formatting-marked-text-minimal"),
    ("japanese", "ime-return-commit-undo"),
    ("japanese", "ime-return-commit-undo-minimal"),
    ("chinese", "ime-candidate-commit"),
    ("chinese", "ime-candidate-commit-minimal"),
)
methods = []
for group, name in method_contract:
    path = root / group / name / "summary.json"
    summary = json.loads(path.read_text(encoding="utf-8"))
    if summary.get("result") != "Passed":
        raise SystemExit(f"{group}/{name}: method did not pass")
    methods.append({
        "group": group,
        "name": name,
        "summary": str(path),
        "result": summary["result"],
        "passedTests": summary["passedTests"],
        "testDurationSeconds": summary["testDurationSeconds"],
    })
groups = []
for group in ("english", "japanese", "chinese"):
    members = [method for method in methods if method["group"] == group]
    groups.append({
        "name": group,
        "result": "Passed",
        "passedTests": sum(method["passedTests"] for method in members),
        "testDurationSeconds": sum(
            method["testDurationSeconds"] for method in members
        ),
    })
wall_duration = finished_at - started_at
aggregate = {
    "schema": 1,
    "runtime": {"osVersion": "26.5", "osBuild": "23F73"},
    "udid": udid,
    "result": "Passed",
    "passedTests": sum(group["passedTests"] for group in groups),
    "failedTests": 0,
    "skippedTests": 0,
    "wallDurationSeconds": wall_duration,
    "groups": groups,
    "methods": methods,
}
if aggregate["passedTests"] != 24:
    raise SystemExit(
        f"sentinel expected 24 passes, found {aggregate['passedTests']}"
    )
if wall_duration > 1200:
    raise SystemExit(
        f"sentinel exceeded 1200-second budget: {wall_duration} seconds"
    )
(root / "summary.json").write_text(
    json.dumps(aggregate, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
PY

print -r -- "PASS tests=24 output=$output"
