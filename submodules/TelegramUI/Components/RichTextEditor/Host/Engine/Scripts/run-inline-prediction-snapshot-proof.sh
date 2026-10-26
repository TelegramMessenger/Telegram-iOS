#!/bin/zsh

set -euo pipefail

readonly root="${0:A:h:h}"
cd "$root"
readonly pinned_udid="FA6F7462-AA97-42FE-9E57-8DA0593CE756"
readonly catalog="UITests/Fixtures/text-input-inline-prediction-batches-ios26.5-v1.json"
readonly group_id="inline-prediction--snapshot-row-v1--interior-accept"

udid=""
xctestrun=""
snapshot=""
output=""
lock_owned=0

function usage() {
  print -u2 -- \
    "Usage: $0 [--lock-owned] --udid UDID --xctestrun PATH " \
    "--snapshot PATH --output PATH"
}

while (( $# > 0 )); do
  case "$1" in
    --lock-owned) lock_owned=1; shift ;;
    --udid|--xctestrun|--snapshot|--output)
      (( $# >= 2 )) || { usage; exit 64; }
      case "$1" in
        --udid) udid="$2" ;;
        --xctestrun) xctestrun="$2" ;;
        --snapshot) snapshot="$2" ;;
        --output) output="$2" ;;
      esac
      shift 2
      ;;
    *) usage; exit 64 ;;
  esac
done

[[ "$udid" == "$pinned_udid" && -f "$xctestrun" &&
   -d "$snapshot" && -n "$output" ]] || { usage; exit 64; }
if (( lock_owned == 0 )); then
  exec Scripts/with-inputdec-simulator-test-lock.sh \
    --udid "$udid" -- "$0" --lock-owned --udid "$udid" \
    --xctestrun "$xctestrun" --snapshot "$snapshot" --output "$output"
fi
[[ -n "${INPUTDEC_XCTEST_LOCK_OWNER_PID:-}" ]] || {
  print -u2 -- "Refusing snapshot proof without the global XCTest lock"
  exit 75
}

xctestrun="${xctestrun:A}"
snapshot="${snapshot:A}"
output="${output:A}"
[[ ! -e "$output" ]] || {
  print -u2 -- "Proof output already exists: $output"
  exit 73
}
mkdir -p "${output:h}"
readonly staging="${output:h}/.${output:t}.partial-$$"
[[ ! -e "$staging" ]] || exit 73
mkdir -p "$staging/iterations"

function publish_failure() {
  local exit_code="$1"
  local message="$2"
  print -r -- "$message" >"$staging/failure.txt"
  mv "$staging" "$output"
  print -u2 -- "$message; evidence=$output"
  exit "$exit_code"
}

for iteration in {1..10}; do
  padded="$(printf '%02d' "$iteration")"
  child="$staging/iterations/iteration-$padded"
  set +e
  INPUTDEC_BATCH_XCTESTRUN="$xctestrun" \
    Scripts/run-text-input-group.sh --lock-owned --prepared-device \
    --audit-external-mutations --udid "$udid" --catalog "$catalog" \
    --group-id "$group_id" --keyboard-snapshot "$snapshot" \
    --output "$child"
  child_status="$?"
  set -e
  (( child_status == 0 )) ||
    publish_failure "$child_status" \
      "Snapshot proof stopped at iteration $iteration"
  python3 Scripts/text_input_batch.py group-resume-check \
    --catalog "$catalog" --group-id "$group_id" \
    --directory "$child" >/dev/null ||
    publish_failure 65 "Snapshot proof iteration $iteration is incomplete"
done

if ! python3 - "$staging/proof-summary.json" \
    "$staging/iterations" "$group_id" <<'PY'
import json
import pathlib
import sys

output = pathlib.Path(sys.argv[1])
iterations = pathlib.Path(sys.argv[2])
group_id = sys.argv[3]
stock_custom = 0
custom_stock = 0
restores = 0
for index in range(1, 11):
    root = iterations / f"iteration-{index:02d}"
    selected = json.loads((root / "selected-group.json").read_text())
    summary = json.loads((root / "group-summary.json").read_text())
    timing = json.loads((root / "group-timing.json").read_text())
    if (selected.get("id") != group_id or summary.get("groupId") != group_id or
            summary.get("result") != "Passed" or
            summary.get("hostObservations") != 8 or
            summary.get("successfulBoundaries") != 7 or
            timing.get("xctestInvocations") != 1 or
            timing.get("snapshotRestores", 0) < 8):
        raise SystemExit("snapshot proof iteration contract differs")
    orders = [batch.get("order") for batch in selected.get("batches", [])]
    if orders != ["stock-custom", "custom-stock",
                  "stock-custom", "custom-stock"]:
        raise SystemExit("snapshot proof host transition order differs")
    stock_custom += orders.count("stock-custom")
    custom_stock += orders.count("custom-stock")
    restores += timing["snapshotRestores"]
    reports = sorted((root / "external-mutation-audit").glob(
        "observation-*/attempt-*/report.json"))
    if len(reports) != 8 or any(
            json.loads(path.read_text()).get("result") != "clean"
            for path in reports):
        raise SystemExit("snapshot proof mutation audit differs")

value = {
    "schema": 1,
    "result": "Passed",
    "iterations": 10,
    "xctestInvocations": 10,
    "physicalObservations": 80,
    "verifiedRestores": restores,
    "stockCustomTransitions": stock_custom,
    "customStockTransitions": custom_stock,
    "semanticFailures": 0,
    "unclassifiedMutations": 0,
    "erasedBoots": 0,
}
if stock_custom != 20 or custom_stock != 20 or restores < 80:
    raise SystemExit("snapshot proof totals differ")
temporary = output.with_name(f".{output.name}.partial")
temporary.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n")
temporary.replace(output)
PY
then
  publish_failure 65 "Snapshot proof aggregation failed"
fi

mv "$staging" "$output"
print -r -- "PASS inline snapshot proof output=$output"
