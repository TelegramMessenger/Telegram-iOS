#!/bin/zsh

set -euo pipefail

readonly root="${0:A:h:h}"
cd "$root"

readonly pinned_udid="FA6F7462-AA97-42FE-9E57-8DA0593CE756"
readonly child_runner="Scripts/run-text-input-group.sh"
readonly expected_contract='{"groups": 28, "erasedBoots": 20, "successfulXCTestInvocations": 28, "successfulBoundaries": 344, "successfulHostBoundaries": 180, "successfulPassBoundaries": 84, "successfulRowBoundaries": 80, "batches": 112, "comparisons": 216, "hostObservations": 432, "repetitions": [1, 2], "orders": ["stock-custom", "custom-stock"]}'
typeset -ar catalogs=(
  "UITests/Fixtures/text-input-ime-batches-ios26.5-v1.json"
  "UITests/Fixtures/text-input-autocorrection-batches-ios26.5-v1.json"
  "UITests/Fixtures/text-input-inline-prediction-batches-ios26.5-v1.json"
)

udid=""
output=""
resume=0
lock_owned=0

function usage() {
  print -u2 -- \
    "Usage: $0 [--resume] [--lock-owned] --udid UDID --output PATH"
}

while (( $# > 0 )); do
  case "$1" in
    --resume)
      resume=1
      shift
      ;;
    --lock-owned)
      lock_owned=1
      shift
      ;;
    --udid|--output)
      (( $# >= 2 )) || {
        usage
        exit 64
      }
      case "$1" in
        --udid) udid="$2" ;;
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

[[ "$udid" == "$pinned_udid" && -n "$output" ]] || {
  usage
  exit 64
}

if (( lock_owned == 0 )); then
  typeset -a resume_argument
  resume_argument=()
  (( resume == 0 )) || resume_argument=(--resume)
  exec Scripts/with-inputdec-simulator-test-lock.sh \
    --udid "$udid" -- \
    "$0" --lock-owned "${resume_argument[@]}" \
    --udid "$udid" --output "$output"
fi
[[ -n "${INPUTDEC_XCTEST_LOCK_OWNER_PID:-}" ]] || {
  print -u2 -- "Refusing certification without the global XCTest lock"
  exit 75
}

testing="${INPUTDEC_BATCH_TESTING:-0}"
test_limit="${INPUTDEC_BATCH_TEST_LIMIT:-0}"
interrupt_after="${INPUTDEC_BATCH_TEST_INTERRUPT_AFTER:-0}"
test_group_ids_csv="${INPUTDEC_BATCH_TEST_GROUP_IDS:-}"
if [[ "$testing" != 1 &&
      ( "$test_limit" != 0 || "$interrupt_after" != 0 ||
        -n "$test_group_ids_csv" ) ]]; then
  print -u2 -- "Test-only batch controls require INPUTDEC_BATCH_TESTING=1"
  exit 64
fi
typeset -a test_group_ids
test_group_ids=()
if [[ -n "$test_group_ids_csv" ]]; then
  test_group_ids=("${(@s:,:)test_group_ids_csv}")
  (( ${#test_group_ids[@]} > 0 )) || {
    print -u2 -- "Test group ID selection is empty"
    exit 64
  }
  typeset -A unique_test_group_ids
  for test_group_id in "${test_group_ids[@]}"; do
    [[ -n "$test_group_id" && -z "${unique_test_group_ids[$test_group_id]:-}" ]] || {
      print -u2 -- "Test group IDs must be nonempty and unique"
      exit 64
    }
    unique_test_group_ids[$test_group_id]=1
  done
fi
if [[ "$testing" == 1 ]]; then
  [[ "$test_limit" == <-> && "$interrupt_after" == <-> ]] || {
    print -u2 -- "Test-only batch controls must be nonnegative integers"
    exit 64
  }
fi
baseline_runner="${INPUTDEC_BATCH_TEST_BASELINE_RUNNER:-Scripts/prepare-inline-keyboard-baseline.sh}"
if [[ "$baseline_runner" != Scripts/prepare-inline-keyboard-baseline.sh &&
      "$testing" != 1 ]]; then
  print -u2 -- "Baseline runner override requires INPUTDEC_BATCH_TESTING=1"
  exit 64
fi

output="${output:A}"
if (( resume == 0 )); then
  [[ ! -e "$output" ]] || {
    print -u2 -- "Output path already exists: $output"
    exit 73
  }
  mkdir -p "$output/batches"
else
  [[ -d "$output" && ! -L "$output" ]] || {
    print -u2 -- "Resume output is missing or invalid: $output"
    exit 73
  }
fi
readonly total_started="$(date +%s)"

needs_inline_baseline=0
if (( ${#test_group_ids[@]} == 0 )); then
  needs_inline_baseline=1
else
  for test_group_id in "${test_group_ids[@]}"; do
    if [[ "$test_group_id" == inline-prediction--snapshot-row-v1--* ]]; then
      needs_inline_baseline=1
      break
    fi
  done
fi
readonly inline_snapshot="$output/inline-keyboard-snapshot-v1"
readonly inline_identity="$output/inline-keyboard-identity-v1.json"
baseline_seconds=0
config_migration=0
if (( resume != 0 && needs_inline_baseline != 0 )) &&
    [[ ! -d "$inline_snapshot" ]]; then
  if python3 - "$output/run-config.json" "$udid" "${catalogs[@]}" <<'PY'
import hashlib
import json
import pathlib
import sys
path = pathlib.Path(sys.argv[1])
try:
    value = json.loads(path.read_text())
except Exception:
    raise SystemExit(1)
expected = {
    "schema": 1,
    "runtime": {"osVersion": "26.5", "osBuild": "23F73"},
    "udid": sys.argv[2],
    "catalogs": [{
        "path": str(pathlib.Path(raw).resolve()),
        "sha256": hashlib.sha256(pathlib.Path(raw).read_bytes()).hexdigest(),
    } for raw in sys.argv[3:]],
}
raise SystemExit(0 if value == expected else 1)
PY
  then
    [[ ! -e "$output/run-config.order-isolation.json" ]] || {
      print -u2 -- "Order-isolation run config was already migrated"
      exit 65
    }
    config_migration=1
  else
    print -u2 -- "Missing baseline cannot be migrated from run config"
    exit 65
  fi
fi
if (( needs_inline_baseline != 0 )); then
  if (( resume == 0 || config_migration != 0 )); then
    baseline_started="$(date +%s)"
    "$baseline_runner" --udid "$udid" --output "$inline_snapshot"
    baseline_seconds=$(( $(date +%s) - baseline_started ))
  fi
  [[ -d "$inline_snapshot" && ! -L "$inline_snapshot" ]] || {
    print -u2 -- "Inline keyboard baseline is missing or invalid"
    exit 65
  }
  python3 - "$inline_snapshot/manifest.json" "$inline_identity" <<'PY'
import json
import pathlib
import sys
manifest = json.loads(pathlib.Path(sys.argv[1]).read_text())
identity = manifest.get("identity")
if not isinstance(identity, dict):
    raise SystemExit("inline snapshot identity is invalid")
path = pathlib.Path(sys.argv[2])
serialized = json.dumps(identity, indent=2, sort_keys=True) + "\n"
if path.exists():
    if path.read_text() != serialized:
        raise SystemExit("inline snapshot identity differs")
else:
    path.write_text(serialized)
PY
  python3 Scripts/text_input_keyboard_snapshot.py verify \
    --snapshot "$inline_snapshot" --identity "$inline_identity" >/dev/null
  if (( config_migration != 0 )); then
    cp "$output/run-config.json" "$output/run-config.order-isolation.json"
  fi
fi

readonly config_candidate="$output/.run-config.partial-$$"
python3 - "$config_candidate" "$udid" \
  "$needs_inline_baseline" "$inline_snapshot" "$inline_identity" \
  "${catalogs[@]}" <<'PY'
import hashlib
import json
import pathlib
import sys

destination = pathlib.Path(sys.argv[1])
catalogs = []
for raw in sys.argv[6:]:
    path = pathlib.Path(raw).resolve()
    catalogs.append({
        "path": str(path),
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
    })
snapshot = None
if sys.argv[3] == "1":
    snapshot_path = pathlib.Path(sys.argv[4]).resolve()
    identity_path = pathlib.Path(sys.argv[5]).resolve()
    manifest_path = snapshot_path / "manifest.json"
    snapshot = {
        "path": str(snapshot_path),
        "manifestSHA256": hashlib.sha256(manifest_path.read_bytes()).hexdigest(),
        "identity": json.loads(identity_path.read_text()),
    }
with destination.open("x", encoding="utf-8") as stream:
    json.dump({
        "schema": 2,
        "runtime": {"osVersion": "26.5", "osBuild": "23F73"},
        "udid": sys.argv[2],
        "catalogs": catalogs,
        "inlineKeyboardSnapshot": snapshot,
    }, stream, indent=2, sort_keys=True)
    stream.write("\n")
PY
if (( resume == 1 )); then
  if (( config_migration != 0 )); then
    mv "$config_candidate" "$output/run-config.json"
  elif ! cmp -s "$config_candidate" "$output/run-config.json"; then
    mv "$config_candidate" "$output/resume-config-mismatch.json"
    print -u2 -- "Resume runtime, device, or catalog hashes differ"
    exit 65
  fi
  rm -f "$config_candidate"
else
  mv "$config_candidate" "$output/run-config.json"
fi

build_seconds=0
source_xctestrun="${INPUTDEC_BATCH_XCTESTRUN:-}"
if [[ -z "$source_xctestrun" && -f "$output/prebuilt-xctestrun.txt" ]]; then
  source_xctestrun="$(<"$output/prebuilt-xctestrun.txt")"
fi
if [[ -z "$source_xctestrun" ]]; then
  readonly build_started="$(date +%s)"
  readonly derived_data="$output/build/DerivedData"
  mkdir -p "$output/build"
  if ! xcodebuild build-for-testing \
      -project InputDec.xcodeproj \
      -scheme InputDec \
      -destination "platform=iOS Simulator,id=${udid}" \
      -parallel-testing-enabled NO \
      -derivedDataPath "$derived_data" \
      >"$output/build/build.log" 2>&1; then
    print -u2 -- "Batched certification build failed; evidence=$output"
    exit 65
  fi
  typeset -a xctestruns
  xctestruns=("$derived_data"/Build/Products/*.xctestrun(N))
  (( ${#xctestruns[@]} == 1 )) || {
    print -u2 -- "Expected exactly one xctestrun after build"
    exit 65
  }
  source_xctestrun="${xctestruns[1]}"
  build_seconds=$(( $(date +%s) - build_started ))
  print -r -- "$source_xctestrun" >"$output/prebuilt-xctestrun.txt"
else
  source_xctestrun="${source_xctestrun:A}"
  [[ -f "$source_xctestrun" ]] || {
    print -u2 -- "Missing prebuilt xctestrun: $source_xctestrun"
    exit 65
  }
  if [[ ! -f "$output/prebuilt-xctestrun.txt" ]]; then
    print -r -- "$source_xctestrun" >"$output/prebuilt-xctestrun.txt"
  fi
fi
readonly source_xctestrun

function write_progress() {
  local completed="$1"
  local total="$2"
  local last_group="$3"
  local partial="$output/.progress.partial-$$"
  python3 - "$partial" "$completed" "$total" "$last_group" <<'PY'
import json
import pathlib
import sys
with pathlib.Path(sys.argv[1]).open("x", encoding="utf-8") as stream:
    json.dump({
        "schema": 1,
        "completedGroups": int(sys.argv[2]),
        "totalGroups": int(sys.argv[3]),
        "lastGroupId": sys.argv[4] or None,
    }, stream, indent=2, sort_keys=True)
    stream.write("\n")
PY
  mv -f "$partial" "$output/progress.json"
}

total_groups=28
(( ${#test_group_ids[@]} == 0 )) || total_groups=${#test_group_ids[@]}
(( testing == 0 || test_limit == 0 || test_limit >= total_groups )) || \
  total_groups="$test_limit"
completed=0
visited=0
executed_this_run=0
last_group=""
stop=0

function group_is_selected_for_test() {
  local candidate="$1"
  (( ${#test_group_ids[@]} == 0 )) && return 0
  local selected
  for selected in "${test_group_ids[@]}"; do
    [[ "$candidate" != "$selected" ]] || return 0
  done
  return 1
}

for catalog in "${catalogs[@]}"; do
  subsystem="$(python3 - "$catalog" <<'PY'
import json
import pathlib
import sys
print(json.loads(pathlib.Path(sys.argv[1]).read_text())["subsystem"])
PY
)"
  typeset -a group_ids
  group_ids=("${(@f)$(python3 Scripts/text_input_batch.py list-groups "$catalog")}")
  for group_id in "${group_ids[@]}"; do
    group_is_selected_for_test "$group_id" || continue
    visited=$(( visited + 1 ))
    if (( visited > total_groups )); then
      stop=1
      break
    fi
    child="$output/batches/$subsystem/$group_id"
    retained=""
    if [[ -e "$child" ]]; then
      if (( resume == 1 )) && python3 Scripts/text_input_batch.py group-resume-check \
          --catalog "$catalog" --group-id "$group_id" \
          --directory "$child" >/dev/null; then
        completed=$(( completed + 1 ))
        last_group="$group_id"
        write_progress "$completed" "$total_groups" "$last_group"
        print -r -- "RESUME group=$group_id"
        continue
      fi
      if (( resume == 0 )); then
        print -u2 -- "Unexpected existing child output: $child"
        exit 73
      fi
      retained="$output/interrupted-attempts/$(date +%Y%m%dT%H%M%S)-${visited}-${group_id}"
      mkdir -p "${retained:h}"
      mv "$child" "$retained"
      print -r -- "PRESERVE invalid group=$group_id path=$retained"
    fi

    typeset -a child_arguments
    child_arguments=(
      --lock-owned --udid "$udid" --catalog "$catalog"
      --group-id "$group_id" --output "$child"
    )
    if [[ "$group_id" == inline-prediction--snapshot-row-v1--* ]]; then
      child_arguments+=(
        --prepared-device --keyboard-snapshot "$inline_snapshot"
      )
      if [[ -n "${retained:-}" &&
            -f "$retained/failure-classification.json" &&
            -d "$retained/checkpoints" ]]; then
        child_arguments+=(--resume-from "$retained")
      fi
    fi
    set +e
    INPUTDEC_BATCH_XCTESTRUN="$source_xctestrun" \
      "$child_runner" "${child_arguments[@]}"
    child_exit="$?"
    set -e
    if (( child_exit != 0 )); then
      print -u2 -- \
        "Batched certification stopped at $group_id status=$child_exit"
      exit "$child_exit"
    fi
    completed=$(( completed + 1 ))
    executed_this_run=$(( executed_this_run + 1 ))
    last_group="$group_id"
    write_progress "$completed" "$total_groups" "$last_group"

    wall_seconds=$(( $(date +%s) - total_started ))
    if (( wall_seconds > 3600 )); then
      print -u2 -- "Batched certification exceeded the 3600-second budget"
      exit 65
    fi
    if (( testing == 1 && interrupt_after > 0 &&
          executed_this_run >= interrupt_after )); then
      print -u2 -- "TEST INTERRUPTION after $executed_this_run new group"
      exit 75
    fi
  done
  (( stop == 0 )) || break
done

if (( testing == 1 && total_groups < 28 )); then
  python3 - "$output/testing-summary.json" "$completed" \
    "$total_groups" <<'PY'
import json
import pathlib
import sys
with pathlib.Path(sys.argv[1]).open("x", encoding="utf-8") as stream:
    json.dump({
        "schema": 1,
        "completedGroups": int(sys.argv[2]),
        "totalGroups": int(sys.argv[3]),
        "result": "Passed",
    }, stream, indent=2, sort_keys=True)
    stream.write("\n")
PY
  print -r -- "PASS testing groups=$completed output=$output"
  exit 0
fi

readonly wall_seconds=$(( $(date +%s) - total_started ))
readonly summary_partial="$output/.summary.partial-$$"
python3 Scripts/text_input_batch.py aggregate \
  --batches-root "$output/batches" \
  --output "$summary_partial" \
  --catalog "${catalogs[1]}" \
  --catalog "${catalogs[2]}" \
  --catalog "${catalogs[3]}" >/dev/null
python3 - "$summary_partial" "$expected_contract" \
  "$build_seconds" "$baseline_seconds" "$wall_seconds" <<'PY'
import json
import pathlib
import sys
path = pathlib.Path(sys.argv[1])
summary = json.loads(path.read_text())
expected = json.loads(sys.argv[2])
for key, value in expected.items():
    if summary.get(key) != value:
        raise SystemExit(f"aggregate {key} differs: {summary.get(key)!r}")
row_reset_seconds = summary["durations"].get("rowResetSeconds")
host_reset_seconds = summary["durations"].get("hostResetSeconds")
if (type(host_reset_seconds) is not int or host_reset_seconds < 0 or
        host_reset_seconds > summary["durations"]["xctestSeconds"]):
    raise SystemExit("aggregate hostResetSeconds is invalid")
if (type(row_reset_seconds) is not int or row_reset_seconds < 0 or
        row_reset_seconds > summary["durations"]["xctestSeconds"]):
    raise SystemExit("aggregate rowResetSeconds is invalid")
if (host_reset_seconds + row_reset_seconds >
        summary["durations"]["xctestSeconds"]):
    raise SystemExit("aggregate boundary reset timing exceeds XCTest")
summary["durations"]["buildSeconds"] = int(sys.argv[3])
summary["durations"]["inlineBaselineSeconds"] = int(sys.argv[4])
summary["durations"]["wallSeconds"] = int(sys.argv[5])
path.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
PY
mv "$summary_partial" "$output/summary.json"
python3 Scripts/text_input_batch.py materialize-authority \
  --source batched --root "$output" \
  --output "$output/authority-observations.json" >/dev/null
print -r -- "PASS batched certification groups=28 batches=112 output=$output"
