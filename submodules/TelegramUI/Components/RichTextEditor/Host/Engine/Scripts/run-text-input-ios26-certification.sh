#!/bin/zsh

set -euo pipefail

readonly root="${0:A:h:h}"
cd "$root"

readonly pinned_udid="FA6F7462-AA97-42FE-9E57-8DA0593CE756"
udid=""
output=""
lock_owned=0

function usage() {
  print -u2 -- "Usage: $0 --udid UDID --output PATH"
}

while (( $# > 0 )); do
  case "$1" in
    --udid|--output)
      (( $# >= 2 )) || { usage; exit 64; }
      case "$1" in
        --udid) udid="$2" ;;
        --output) output="$2" ;;
      esac
      shift 2
      ;;
    --lock-owned)
      lock_owned=1
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
[[ -n "$output" ]] || { usage; exit 64; }

if (( lock_owned == 0 )); then
  exec Scripts/with-inputdec-simulator-test-lock.sh \
    --udid "$udid" -- \
    "$0" --lock-owned --udid "$udid" --output "$output"
fi
[[ -n "${INPUTDEC_XCTEST_LOCK_OWNER_PID:-}" ]] || {
  print -u2 -- "Refusing certification without the global XCTest lock"
  exit 75
}
[[ ! -e "$output" ]] || {
  print -u2 -- "Output path already exists: $output"
  exit 73
}

mkdir -p "$output"
readonly fast_output="$output/fast"
readonly keyboard_output="$output/keyboard-sentinels"
readonly ime_output="$output/ime"
readonly autocorrection_output="$output/autocorrection"
readonly inline_prediction_output="$output/inline-prediction"

Scripts/run-text-input-fast.sh \
  --udid "$udid" --output "$fast_output"
Scripts/run-text-input-keyboard-sentinels.sh \
  --lock-owned --udid "$udid" --output "$keyboard_output"
Scripts/run-ime-complete-matrix.sh \
  --udid "$udid" --repetitions 2 \
  --orders stock-custom,custom-stock --output "$ime_output"
Scripts/run-autocorrection-complete-matrix.sh \
  "$udid" "$autocorrection_output" 26.5 23F73
Scripts/run-inline-prediction-complete-matrix.sh \
  "$udid" "$inline_prediction_output" 26.5 23F73

python3 - "$autocorrection_output" "$inline_prediction_output" <<'PY'
import json
import pathlib
import sys


def summarize(root, logical_rows, expected_comparisons):
    parity_paths = sorted(root.glob("*/parity.json"))
    if len(parity_paths) != expected_comparisons:
        raise SystemExit(
            f"{root}: expected {expected_comparisons} comparisons, "
            f"observed {len(parity_paths)}"
        )
    bundles = []
    for path in parity_paths:
        parity = json.loads(path.read_text(encoding="utf-8"))
        if parity.get("result") != "passed":
            raise SystemExit(f"{path}: child comparison did not pass")
        for key in ("stockBundle", "customBundle"):
            bundle = pathlib.Path(parity.get(key, ""))
            if not bundle.is_dir():
                raise SystemExit(f"{path}: missing {key} {bundle}")
            bundles.append(str(bundle.resolve()))
    if len(bundles) != len(set(bundles)):
        raise SystemExit(f"{root}: reused host result bundle")
    summary = {
        "schema": 1,
        "runtime": {"osVersion": "26.5", "osBuild": "23F73"},
        "udid": "FA6F7462-AA97-42FE-9E57-8DA0593CE756",
        "logicalRows": logical_rows,
        "repetitions": 2,
        "orders": ["stock-custom", "custom-stock"],
        "comparisons": len(parity_paths),
        "hostExecutions": len(bundles),
        "result": "Passed",
    }
    (root / "summary.json").write_text(
        json.dumps(summary, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )


summarize(pathlib.Path(sys.argv[1]), 21, 84)
summarize(pathlib.Path(sys.argv[2]), 9, 36)
PY

python3 - "$output" "$udid" <<'PY'
import json
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
udid = sys.argv[2]
paths = {
    "fast": root / "fast/summary.json",
    "keyboardSentinels": root / "keyboard-sentinels/summary.json",
    "ime": root / "ime/summary.json",
    "autocorrection": root / "autocorrection/summary.json",
    "inlinePrediction": root / "inline-prediction/summary.json",
}
children = {}
for name, path in paths.items():
    if not path.is_file():
        raise SystemExit(f"missing child summary: {path}")
    children[name] = json.loads(path.read_text(encoding="utf-8"))

for name in ("fast", "keyboardSentinels", "autocorrection",
             "inlinePrediction"):
    if children[name].get("result") != "Passed":
        raise SystemExit(f"{name} child summary did not pass")
fast = children["fast"]
if (
    fast.get("failedTests") != 0
    or fast.get("skippedTests") != 0
    or fast.get("passedTests", 0) <= 0
):
    raise SystemExit("fast child summary is incomplete")
sentinels = children["keyboardSentinels"]
if (
    sentinels.get("passedTests") != 24
    or sentinels.get("failedTests") != 0
    or sentinels.get("skippedTests") != 0
):
    raise SystemExit("keyboard-sentinel child summary is incomplete")
ime = children["ime"]
if (
    ime.get("logicalRows") != 24
    or ime.get("comparisons") != 96
    or ime.get("hostExecutions") != 192
    or ime.get("repetitions") != 2
    or ime.get("orders") != ["stock-custom", "custom-stock"]
):
    raise SystemExit("IME child summary is incomplete")
for name, logical_rows, comparisons, hosts in (
    ("autocorrection", 21, 84, 168),
    ("inlinePrediction", 9, 36, 72),
):
    child = children[name]
    if (
        child.get("logicalRows") != logical_rows
        or child.get("comparisons") != comparisons
        or child.get("hostExecutions") != hosts
        or child.get("repetitions") != 2
        or child.get("orders") != ["stock-custom", "custom-stock"]
    ):
        raise SystemExit(f"{name} child summary is incomplete")
for name in ("keyboardSentinels", "ime", "autocorrection",
             "inlinePrediction"):
    child = children[name]
    if (
        child.get("runtime")
        != {"osVersion": "26.5", "osBuild": "23F73"}
        or child.get("udid") != udid
    ):
        raise SystemExit(f"{name} child runtime is not pinned")

summary = {
    "schema": 1,
    "runtime": {"osVersion": "26.5", "osBuild": "23F73"},
    "udid": udid,
    "childPaths": {name: str(path) for name, path in paths.items()},
    "logicalRows": {
        "fastSemanticScenarios": 54,
        "keyboardSentinels": 8,
        "ime": 24,
        "autocorrection": 21,
        "inlinePrediction": 9,
    },
    "comparisonCount": 216,
    "hostExecutionCount": 432,
    "overallResult": "Passed",
}
(root / "summary.json").write_text(
    json.dumps(summary, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
PY

python3 Scripts/text_input_batch.py materialize-authority \
  --source fresh --root "$output" \
  --output "$output/authority-observations.json" >/dev/null
print -r -- "PASS iOS 26.5 certification output=$output"
