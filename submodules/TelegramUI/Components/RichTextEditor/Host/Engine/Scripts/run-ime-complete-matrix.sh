#!/bin/zsh

set -euo pipefail

readonly root="${0:A:h:h}"
cd "$root"

readonly pinned_udid="FA6F7462-AA97-42FE-9E57-8DA0593CE756"
udid=""
repetitions=""
orders=""
output=""
resume=0

function usage() {
  print -u2 -- \
    "Usage: $0 --udid UDID --repetitions 2 " \
    "--orders stock-custom,custom-stock --output PATH"
}

while (( $# > 0 )); do
  case "$1" in
    --resume)
      resume=1
      shift
      ;;
    --udid|--repetitions|--orders|--output)
      (( $# >= 2 )) || { usage; exit 64; }
      case "$1" in
        --udid) udid="$2" ;;
        --repetitions) repetitions="$2" ;;
        --orders) orders="$2" ;;
        --output) output="$2" ;;
      esac
      shift 2
      ;;
    *) usage; exit 64 ;;
  esac
done

[[ "$udid" == "$pinned_udid" ]] || {
  print -u2 -- "Refusing non-K3 simulator: $udid"; exit 64
}
[[ "$repetitions" == "2" ]] || {
  print -u2 -- "Complete IME matrix requires exactly two repetitions"; exit 64
}
[[ "$orders" == "stock-custom,custom-stock" ]] || {
  print -u2 -- "Complete IME matrix requires both frozen host orders"; exit 64
}
[[ -n "$output" ]] || { usage; exit 64; }
[[ ! -e "$output" || "$resume" == 1 ]] || {
  print -u2 -- "Output path already exists: $output"; exit 73
}
overlap="$(ps -axo pid=,command= |
  rg 'xcodebuild test( |$)' | rg "$pinned_udid" | rg -v 'rg ' || true)"
[[ -z "$overlap" ]] || {
  print -r -- "$overlap"
  print -u2 -- "Refusing overlapping XCTest run"
  exit 75
}

mkdir -p "$output"
for order in stock-custom custom-stock; do
  resume_argument=()
  (( resume == 1 )) && resume_argument=(--resume)
  Scripts/run-ime-stock-truth.sh \
    "${resume_argument[@]}" \
    --udid "$udid" --language all --location interior \
    --decision candidate-commit,cancel,ordinary-commit \
    --host both --order "$order" --repetitions "$repetitions" \
    --output "$output/$order-interior"
  Scripts/run-ime-stock-truth.sh \
    "${resume_argument[@]}" \
    --udid "$udid" --language all --location boundary \
    --decision candidate-commit,cancel,ordinary-commit \
    --host both --order "$order" --repetitions "$repetitions" \
    --output "$output/$order-boundary"
  Scripts/run-ime-stock-truth.sh \
    "${resume_argument[@]}" \
    --udid "$udid" --language all \
    --decision return-commit-then-undo,responder-loss \
    --host both --order "$order" --repetitions "$repetitions" \
    --output "$output/$order-terminal"
done

python3 - "$output" <<'PY'
import json
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
comparisons = sorted(root.rglob("comparison.json"))
lifecycles = sorted(root.rglob("lifecycle.json"))
provisioning = [
    path.parent / "provisioning" / "summary.json"
    for path in lifecycles
]
results = [
    path.parent / f"{path.parent.name}.xcresult"
    for path in lifecycles
]
if len(comparisons) != 96:
    raise SystemExit(f"expected comparisons=96, observed {len(comparisons)}")
if len(lifecycles) != 192:
    raise SystemExit(f"expected hostExecutions=192, observed {len(lifecycles)}")
if (len(provisioning) != 192 or len(results) != 192 or
        not all(path.is_file() for path in provisioning) or
        not all(path.is_dir() for path in results)):
    raise SystemExit(
        "every host execution must have distinct provisioning and xcresult evidence")
for collection in (comparisons, lifecycles, provisioning, results):
    resolved = [str(path.resolve()) for path in collection]
    if len(resolved) != len(set(resolved)):
        raise SystemExit("reused host evidence path")
summary = {
    "schema": 1,
    "runtime": {"osVersion": "26.5", "osBuild": "23F73"},
    "udid": "FA6F7462-AA97-42FE-9E57-8DA0593CE756",
    "logicalRows": 24,
    "repetitions": 2,
    "orders": ["stock-custom", "custom-stock"],
    "comparisons": len(comparisons),
    "hostExecutions": len(lifecycles),
    "comparisonPaths": [str(path) for path in comparisons],
    "hostEvidencePaths": [str(path.parent) for path in lifecycles],
}
(root / "summary.json").write_text(
    json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
PY

print -r -- "PASS comparisons=96 hostExecutions=192 output=$output"
