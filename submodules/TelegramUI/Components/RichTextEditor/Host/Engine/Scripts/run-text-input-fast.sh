#!/bin/zsh

set -euo pipefail

readonly root="${0:A:h:h}"
cd "$root"

readonly pinned_udid="FA6F7462-AA97-42FE-9E57-8DA0593CE756"
udid=""
output=""
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
[[ ! -e "$output" ]] || {
  print -u2 -- "Output path already exists: $output"
  exit 73
}

mkdir -p "$output"
readonly result="$output/fast-text-input.xcresult"
readonly log="$output/xcodebuild.log"
readonly raw_summary="$output/xcresult-summary.json"
readonly summary="$output/summary.json"
action="test"
(( without_building == 1 )) && action="test-without-building"

command=(
  xcodebuild "$action"
  -project InputDec.xcodeproj
  -scheme InputDec
  -destination "platform=iOS Simulator,id=${udid}"
  -parallel-testing-enabled NO
  -collect-test-diagnostics never
  -resultBundlePath "$result"
  -only-testing:InputDecTests/IDTextInputFastLifecycleTests
  -only-testing:InputDecTests/IDTextInputScenarioTests
  -only-testing:InputDecTests/IDTextInputStateRecorderTests
  -only-testing:InputDecTests/IDTextInputTransactionDriverTests
  -only-testing:InputDecTests/IDTextInputDifferentialRunnerTests
  -only-testing:InputDecTests/IDInlineFormattingDifferentialTests
  -only-testing:InputDecTests/IDIMECompositionLifecycleContractTests
  -only-testing:InputDecTests/IDAutocorrectionDecisionContractTests
  -only-testing:InputDecTests/IDInlinePredictionLifecycleContractTests
  -only-testing:InputDecTests/IDPrivateUIKitTests
  -only-testing:InputDecTests/IDProjectSmokeTests
)
[[ -z "$derived_data_path" ]] || command+=(
  -derivedDataPath "$derived_data_path"
)

set +e
Scripts/with-inputdec-simulator-test-lock.sh \
  --udid "$udid" -- "${command[@]}" >"$log" 2>&1
test_status="$?"
set -e

if [[ -d "$result" ]]; then
  xcrun xcresulttool get test-results summary \
    --path "$result" >"$raw_summary"
  python3 - "$raw_summary" "$summary" <<'PY'
import json
import pathlib
import sys

source = json.loads(pathlib.Path(sys.argv[1]).read_text())
start = source.get("startTime")
finish = source.get("finishTime")
duration = (
    finish - start
    if isinstance(start, (int, float)) and isinstance(finish, (int, float))
    else None
)
summary = {
    "result": source.get("result"),
    "passedTests": source.get("passedTests", 0),
    "failedTests": source.get("failedTests", 0),
    "skippedTests": source.get("skippedTests", 0),
    "startTime": start,
    "finishTime": finish,
    "testDurationSeconds": duration,
}
pathlib.Path(sys.argv[2]).write_text(
    json.dumps(summary, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
if (
    summary["result"] != "Passed"
    or summary["failedTests"] != 0
    or summary["skippedTests"] != 0
    or not isinstance(duration, (int, float))
    or duration > 30.0
):
    raise SystemExit(
        "fast text-input gate requires Passed, zero failures/skips, "
        "and testDurationSeconds <= 30"
    )
PY
fi

if (( test_status != 0 )); then
  print -u2 -- "Fast text-input gate failed; see $log"
  exit "$test_status"
fi
[[ -f "$summary" ]] || {
  print -u2 -- "Fast text-input gate produced no summary"
  exit 65
}
print -r -- "PASS output=$output"
