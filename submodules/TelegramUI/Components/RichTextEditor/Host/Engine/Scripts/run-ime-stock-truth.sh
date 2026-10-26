#!/bin/zsh

set -euo pipefail

readonly root="${0:A:h:h}"
cd "$root"

readonly pinned_udid="FA6F7462-AA97-42FE-9E57-8DA0593CE756"
readonly expected_os_version="26.5"
readonly expected_os_build="23F73"
readonly keyboard_readiness_diagnostic='Failed to determine hittability of "(k|n)" Key: Activation point invalid and no suggested hit points based on element frame'

simulator_udid=""
language=""
repetitions=""
output_directory=""
location="all"
host="stock"
order="stock-custom"
decision_filter="all"
resume=0

function usage() {
  print -u2 -- \
    "Usage: $0 --udid UDID --language LANGUAGE " \
    "[--location all|interior|boundary] " \
    "[--decision candidate-commit,cancel,ordinary-commit|" \
    "return-commit-then-undo,responder-loss] " \
    "[--host stock|custom|both] [--order stock-custom|custom-stock] " \
    "--repetitions COUNT --output PATH"
  print -u2 -- \
    "Boundary: $0 --language all --location boundary " \
    "--decision candidate-commit,cancel,ordinary-commit --host both ..."
}

while (( $# > 0 )); do
  case "$1" in
    --resume)
      resume=1
      shift
      ;;
    --udid|--language|--location|--decision|--host|--order|--repetitions|--output)
      if (( $# < 2 )); then
        usage
        exit 64
      fi
      case "$1" in
        --udid) simulator_udid="$2" ;;
        --language) language="$2" ;;
        --location) location="$2" ;;
        --decision) decision_filter="$2" ;;
        --host) host="$2" ;;
        --order) order="$2" ;;
        --repetitions) repetitions="$2" ;;
        --output) output_directory="$2" ;;
      esac
      shift 2
      ;;
    *)
      print -u2 -- "Unknown argument: $1"
      usage
      exit 64
      ;;
  esac
done

if [[ -z "$simulator_udid" || -z "$language" ||
      -z "$repetitions" || -z "$output_directory" ]]; then
  usage
  exit 64
fi
if [[ "$location" != "all" && "$location" != "interior" &&
      "$location" != "boundary" ]]; then
  print -u2 -- "Unsupported IME location: $location"
  exit 64
fi
if [[ "$host" != "stock" && "$host" != "custom" &&
      "$host" != "both" ]]; then
  print -u2 -- "Unsupported IME host: $host"
  exit 64
fi
if [[ "$order" != "stock-custom" && "$order" != "custom-stock" ]]; then
  print -u2 -- "Unsupported IME host order: $order"
  exit 64
fi
if [[ "$decision_filter" != "all" &&
      "$decision_filter" != "candidate-commit,cancel,ordinary-commit" &&
      "$decision_filter" != "return-commit-then-undo,responder-loss" ]]; then
  print -u2 -- "Unsupported IME decision filter: $decision_filter"
  exit 64
fi
if [[ "$location" == "boundary" &&
      "$decision_filter" != "candidate-commit,cancel,ordinary-commit" ]]; then
  print -u2 -- \
    "Boundary differential requires --decision candidate-commit,cancel,ordinary-commit"
  exit 64
fi
if [[ "$host" != "stock" &&
      ("$language" != "all" ||
       ("$location" != "all" && "$location" != "interior" &&
        "$location" != "boundary")) ]]; then
  print -u2 -- \
    "Custom IME differential requires --language all with --location all, interior, or boundary"
  exit 64
fi
if [[ "$simulator_udid" != "$pinned_udid" ]]; then
  print -u2 -- "Refusing non-K3 simulator: $simulator_udid"
  exit 64
fi
if [[ "$language" != "japanese-romaji" &&
      "$language" != "simplified-chinese-pinyin" &&
      "$language" != "all" ]]; then
  print -u2 -- "Unsupported IME language: $language"
  exit 64
fi
case "$repetitions" in
  ''|0|*[!0-9]*)
    print -u2 -- "Repetitions must be a positive integer: $repetitions"
    exit 64
    ;;
esac
if [[ -e "$output_directory" && "$resume" != 1 ]]; then
  print -u2 -- "Output path already exists: $output_directory"
  exit 73
fi

function require_no_overlapping_tests() {
  local overlap
  overlap="$(ps -axo pid=,command= |
    rg 'xcodebuild test( |$)' |
    rg "$pinned_udid" |
    rg -v 'rg ' || true)"
  if [[ -n "$overlap" ]]; then
    print -r -- "$overlap"
    print -u2 -- "Refusing overlapping XCTest run"
    return 75
  fi
}

case "$language" in
  japanese-romaji)
    readonly test_method="testStockJapaneseRomajiDiscoveryTruth"
    ;;
  simplified-chinese-pinyin)
    readonly test_method="testStockSimplifiedChinesePinyinDiscoveryTruth"
    ;;
esac

require_no_overlapping_tests
mkdir -p "$output_directory"

function capture_complete_row() {
  local row_host="$1"
  local row_language="$2"
  local decision="$3"
  local test_method="$4"
  local observation="$5"
  local provisioning="$observation/provisioning"
  local result="$observation/$row_host.xcresult"
  local log="$observation/$row_host.log"
  local summary="$observation/$row_host-summary.json"
  local attachments="$observation/attachments"
  local lifecycle="$observation/lifecycle.json"
  local retained_root="$observation/readiness-attempts"
  local -a retained_attempts
  retained_attempts=("$retained_root"/attempt-*(N))
  local attempt=$(( ${#retained_attempts[@]} + 1 ))
  if (( attempt > 3 )); then
    print -u2 -- \
      "Keyboard-service readiness attempts already exhausted: $observation"
    return 65
  fi

  while true; do
    mkdir -p "$observation"
    require_no_overlapping_tests
    xcrun simctl shutdown "$simulator_udid" 2>/dev/null || true
    xcrun simctl erase "$simulator_udid"
    xcrun simctl boot "$simulator_udid"
    xcrun simctl bootstatus "$simulator_udid" -b
    Scripts/provision-ime-keyboards.sh "$simulator_udid" "$provisioning"
    require_no_overlapping_tests

    print -r -- \
      "START $row_host $row_language $test_method attempt $attempt"
    if xcodebuild test \
      -project InputDec.xcodeproj \
      -scheme InputDec \
      -destination "platform=iOS Simulator,id=$simulator_udid" \
      -parallel-testing-enabled NO \
      -collect-test-diagnostics never \
      "-only-testing:InputDecUITests/IDIMECompositionLifecycleUITests/$test_method" \
      -resultBundlePath "$result" >"$log" 2>&1; then
      break
    fi
    if (( attempt < 3 )) &&
        rg -q -- "$keyboard_readiness_diagnostic" "$log"; then
      local retained="$retained_root/attempt-$attempt"
      mkdir -p "$retained"
      mv "$provisioning" "$result" "$log" "$retained/"
      print -r -- \
        "RETRY keyboard-service-not-ready $row_host $row_language attempt $attempt"
      attempt=$((attempt + 1))
      continue
    fi
    tail -200 "$log"
    return 65
  done
  xcrun xcresulttool get test-results summary \
    --path "$result" --compact >"$summary"
  Scripts/validate-autocorrection-summary.py \
    "$summary" "$simulator_udid" \
    "$expected_os_version" "$expected_os_build"
  xcrun xcresulttool export attachments \
    --path "$result" --output-path "$attachments"
  python3 - "$attachments" "$decision" "$test_method" "$lifecycle" <<'PY'
import json
import pathlib
import sys

attachments_path, decision, method, output_path = sys.argv[1:]
attachments_path = pathlib.Path(attachments_path)
manifest = json.loads(
    (attachments_path / "manifest.json").read_text(encoding="utf-8"))
if len(manifest) != 1 or not manifest[0]["testIdentifier"].endswith(method):
    raise SystemExit(f"unexpected test identity for {method}")
records = manifest[0]["attachments"]
if decision == "candidate-commit":
    expected = [
        "baseline", "firstComposition", "updatedComposition",
        "candidateVisible", "decision", "immediate", "quiesced",
    ]
elif decision in {"cancel", "ordinary-commit"}:
    expected = [
        "baseline", "firstComposition", "updatedComposition",
        "decision", "immediate", "quiesced",
    ]
elif decision == "return-commit-then-undo":
    expected = [
        "baseline", "firstComposition", "updatedComposition",
        "decision", "immediate", "quiesced", "undo",
    ]
elif decision == "responder-loss":
    expected = [
        "baseline", "firstComposition", "updatedComposition",
        "decision", "postInterruption", "quiesced",
    ]
else:
    raise SystemExit(f"unsupported decision {decision}")
phases = []
for phase in expected:
    prefix = f"ime-composition-{phase}-status_"
    matches = [
        record for record in records
        if record["suggestedHumanReadableName"].startswith(prefix)
    ]
    if len(matches) != 1:
        raise SystemExit(
            f"missing or duplicate status attachment for {phase}")
    status_path = attachments_path / matches[0]["exportedFileName"]
    phases.append({
        "phase": phase,
        "status": json.loads(status_path.read_text(encoding="utf-8")),
    })
pathlib.Path(output_path).write_text(json.dumps({
    "schema": 1,
    "testMethod": method,
    "decision": decision,
    "phases": phases,
}, indent=2, ensure_ascii=False, sort_keys=True) + "\n", encoding="utf-8")
PY
  print -r -- \
    "PASS $row_host $row_language $test_method"
}

function capture_complete_pair() {
  local row_language="$1"
  local decision="$2"
  local stock_method="$3"
  local custom_method="$4"
  local pair="$5"
  local -a pair_hosts
  if [[ "$host" == "stock" ]]; then
    pair_hosts=(stock)
  elif [[ "$host" == "custom" ]]; then
    pair_hosts=(custom)
  elif [[ "$order" == "stock-custom" ]]; then
    pair_hosts=(stock custom)
  else
    pair_hosts=(custom stock)
  fi
  local row_host
  for row_host in "${pair_hosts[@]}"; do
    if [[ -f "$pair/$row_host/lifecycle.json" ]]; then
      print -r -- "RESUME $row_host $row_language $decision"
      continue
    fi
    local unexpected=""
    if [[ -d "$pair/$row_host" ]]; then
      unexpected="$(find "$pair/$row_host" -mindepth 1 -maxdepth 1 \
        ! -name readiness-attempts -print -quit)"
    fi
    if [[ -n "$unexpected" ]]; then
      print -u2 -- "Refusing incomplete nonempty host evidence: $pair/$row_host"
      return 73
    fi
    if [[ "$row_host" == "stock" ]]; then
      capture_complete_row \
        stock "$row_language" "$decision" "$stock_method" "$pair/stock"
    else
      capture_complete_row \
        custom "$row_language" "$decision" "$custom_method" "$pair/custom"
    fi
  done
  if [[ "$host" == "both" ]]; then
    python3 Scripts/compare-ime-composition-results.py \
      --stock "$pair/stock/lifecycle.json" \
      --custom "$pair/custom/lifecycle.json" \
      --tolerance 1.0 \
      --output "$pair/comparison.json"
  fi
}

if [[ "$language" == "all" && "$location" == "all" &&
      "$decision_filter" == "return-commit-then-undo,responder-loss" ]]; then
  typeset -a terminal_languages terminal_locations terminal_decisions
  typeset -a terminal_stock_methods terminal_custom_methods
  terminal_languages=(
    japanese-romaji japanese-romaji japanese-romaji
    simplified-chinese-pinyin simplified-chinese-pinyin
    simplified-chinese-pinyin
  )
  terminal_locations=(
    before-boundary before-boundary after-boundary
    before-boundary before-boundary after-boundary
  )
  terminal_decisions=(
    return-commit-then-undo responder-loss return-commit-then-undo
    return-commit-then-undo responder-loss return-commit-then-undo
  )
  terminal_stock_methods=(
    testStockJapaneseBeforeBoundaryReturnCommitThenUndoTruth
    testStockJapaneseBeforeBoundaryResponderLossTruth
    testStockJapaneseAfterBoundaryReturnCommitThenUndoTruth
    testStockSimplifiedChinesePinyinBeforeBoundaryReturnCommitThenUndoTruth
    testStockSimplifiedChinesePinyinBeforeBoundaryResponderLossTruth
    testStockSimplifiedChinesePinyinAfterBoundaryReturnCommitThenUndoTruth
  )
  terminal_custom_methods=(
    testCustomJapaneseBeforeBoundaryReturnCommitThenUndoTruth
    testCustomJapaneseBeforeBoundaryResponderLossTruth
    testCustomJapaneseAfterBoundaryReturnCommitThenUndoTruth
    testCustomSimplifiedChinesePinyinBeforeBoundaryReturnCommitThenUndoTruth
    testCustomSimplifiedChinesePinyinBeforeBoundaryResponderLossTruth
    testCustomSimplifiedChinesePinyinAfterBoundaryReturnCommitThenUndoTruth
  )
  completed=0
  for repetition in $(seq 1 "$repetitions"); do
    for row_index in {1..6}; do
      row_language="${terminal_languages[$row_index]}"
      row_location="${terminal_locations[$row_index]}"
      decision="${terminal_decisions[$row_index]}"
      pair="$output_directory/repetition-$repetition/row-$row_index-$row_language-$row_location-$decision"
      if [[ "$resume" == 1 && -f "$pair/comparison.json" ]]; then
        print -r -- "RESUME comparison $pair"
        completed=$((completed + 1))
        continue
      fi
      capture_complete_pair "$row_language" "$decision" \
        "${terminal_stock_methods[$row_index]}" \
        "${terminal_custom_methods[$row_index]}" "$pair"
      completed=$((completed + 1))
    done
  done
  print -r -- \
    "Captured $completed independently erased IME terminal rows for host=$host in $output_directory"
  exit 0
fi

if [[ "$language" == "all" && "$location" == "interior" ]]; then
  typeset -a interior_languages interior_decisions
  typeset -a interior_stock_methods interior_custom_methods
  interior_languages=(
    japanese-romaji japanese-romaji japanese-romaji
    simplified-chinese-pinyin simplified-chinese-pinyin
    simplified-chinese-pinyin
  )
  interior_decisions=(
    candidate-commit cancel ordinary-commit
    candidate-commit cancel ordinary-commit
  )
  interior_stock_methods=(
    testStockJapaneseInteriorCandidateCommitTruth
    testStockJapaneseInteriorCancelTruth
    testStockJapaneseInteriorOrdinaryCommitTruth
    testStockSimplifiedChinesePinyinInteriorCandidateCommitTruth
    testStockSimplifiedChinesePinyinInteriorCancelTruth
    testStockSimplifiedChinesePinyinInteriorOrdinaryCommitTruth
  )
  interior_custom_methods=(
    testCustomJapaneseInteriorCandidateCommitTruth
    testCustomJapaneseInteriorCancelTruth
    testCustomJapaneseInteriorOrdinaryCommitTruth
    testCustomSimplifiedChinesePinyinInteriorCandidateCommitTruth
    testCustomSimplifiedChinesePinyinInteriorCancelTruth
    testCustomSimplifiedChinesePinyinInteriorOrdinaryCommitTruth
  )
  completed=0
  for repetition in $(seq 1 "$repetitions"); do
    for row_index in {1..6}; do
      row_language="${interior_languages[$row_index]}"
      decision="${interior_decisions[$row_index]}"
      pair="$output_directory/repetition-$repetition/row-$row_index-$row_language-$decision"
      if [[ "$resume" == 1 && -f "$pair/comparison.json" ]]; then
        print -r -- "RESUME comparison $pair"
        completed=$((completed + 1))
        continue
      fi
      capture_complete_pair "$row_language" "$decision" \
        "${interior_stock_methods[$row_index]}" \
        "${interior_custom_methods[$row_index]}" "$pair"
      completed=$((completed + 1))
    done
  done
  print -r -- \
    "Captured $completed independently erased IME interior rows for host=$host in $output_directory"
  exit 0
fi

if [[ "$language" == "all" && "$location" == "boundary" ]]; then
  typeset -a boundary_languages boundary_locations boundary_decisions
  typeset -a boundary_stock_methods boundary_custom_methods
  boundary_languages=(
    japanese-romaji japanese-romaji japanese-romaji
    japanese-romaji japanese-romaji japanese-romaji
    simplified-chinese-pinyin simplified-chinese-pinyin
    simplified-chinese-pinyin simplified-chinese-pinyin
    simplified-chinese-pinyin simplified-chinese-pinyin
  )
  boundary_locations=(
    before-boundary before-boundary before-boundary
    after-boundary after-boundary after-boundary
    before-boundary before-boundary before-boundary
    after-boundary after-boundary after-boundary
  )
  boundary_decisions=(
    candidate-commit cancel ordinary-commit
    candidate-commit cancel ordinary-commit
    candidate-commit cancel ordinary-commit
    candidate-commit cancel ordinary-commit
  )
  boundary_stock_methods=(
    testStockJapaneseBeforeBoundaryCandidateCommitTruth
    testStockJapaneseBeforeBoundaryCancelTruth
    testStockJapaneseBeforeBoundaryOrdinaryCommitTruth
    testStockJapaneseAfterBoundaryCandidateCommitTruth
    testStockJapaneseAfterBoundaryCancelTruth
    testStockJapaneseAfterBoundaryOrdinaryCommitTruth
    testStockSimplifiedChinesePinyinBeforeBoundaryCandidateCommitTruth
    testStockSimplifiedChinesePinyinBeforeBoundaryCancelTruth
    testStockSimplifiedChinesePinyinBeforeBoundaryOrdinaryCommitTruth
    testStockSimplifiedChinesePinyinAfterBoundaryCandidateCommitTruth
    testStockSimplifiedChinesePinyinAfterBoundaryCancelTruth
    testStockSimplifiedChinesePinyinAfterBoundaryOrdinaryCommitTruth
  )
  boundary_custom_methods=(
    testCustomJapaneseBeforeBoundaryCandidateCommitTruth
    testCustomJapaneseBeforeBoundaryCancelTruth
    testCustomJapaneseBeforeBoundaryOrdinaryCommitTruth
    testCustomJapaneseAfterBoundaryCandidateCommitTruth
    testCustomJapaneseAfterBoundaryCancelTruth
    testCustomJapaneseAfterBoundaryOrdinaryCommitTruth
    testCustomSimplifiedChinesePinyinBeforeBoundaryCandidateCommitTruth
    testCustomSimplifiedChinesePinyinBeforeBoundaryCancelTruth
    testCustomSimplifiedChinesePinyinBeforeBoundaryOrdinaryCommitTruth
    testCustomSimplifiedChinesePinyinAfterBoundaryCandidateCommitTruth
    testCustomSimplifiedChinesePinyinAfterBoundaryCancelTruth
    testCustomSimplifiedChinesePinyinAfterBoundaryOrdinaryCommitTruth
  )
  completed=0
  for repetition in $(seq 1 "$repetitions"); do
    for row_index in {1..12}; do
      row_language="${boundary_languages[$row_index]}"
      row_location="${boundary_locations[$row_index]}"
      decision="${boundary_decisions[$row_index]}"
      pair="$output_directory/repetition-$repetition/row-$row_index-$row_language-$row_location-$decision"
      if [[ "$resume" == 1 && -f "$pair/comparison.json" ]]; then
        print -r -- "RESUME comparison $pair"
        completed=$((completed + 1))
        continue
      fi
      capture_complete_pair "$row_language" "$decision" \
        "${boundary_stock_methods[$row_index]}" \
        "${boundary_custom_methods[$row_index]}" "$pair"
      completed=$((completed + 1))
    done
  done
  print -r -- \
    "Captured $completed independently erased IME boundary rows for host=$host in $output_directory"
  exit 0
fi

if [[ "$language" == "all" ]]; then
  typeset -a stock_test_methods
  typeset -a stock_test_languages
  typeset -a stock_test_decisions
  stock_test_methods=(
    testStockJapaneseInteriorCandidateCommitTruth
    testStockJapaneseInteriorCancelTruth
    testStockJapaneseInteriorOrdinaryCommitTruth
    testStockJapaneseBeforeBoundaryCandidateCommitTruth
    testStockJapaneseBeforeBoundaryCancelTruth
    testStockJapaneseBeforeBoundaryOrdinaryCommitTruth
    testStockJapaneseBeforeBoundaryReturnCommitThenUndoTruth
    testStockJapaneseBeforeBoundaryResponderLossTruth
    testStockJapaneseAfterBoundaryCandidateCommitTruth
    testStockJapaneseAfterBoundaryCancelTruth
    testStockJapaneseAfterBoundaryOrdinaryCommitTruth
    testStockJapaneseAfterBoundaryReturnCommitThenUndoTruth
    testStockSimplifiedChinesePinyinInteriorCandidateCommitTruth
    testStockSimplifiedChinesePinyinInteriorCancelTruth
    testStockSimplifiedChinesePinyinInteriorOrdinaryCommitTruth
    testStockSimplifiedChinesePinyinBeforeBoundaryCandidateCommitTruth
    testStockSimplifiedChinesePinyinBeforeBoundaryCancelTruth
    testStockSimplifiedChinesePinyinBeforeBoundaryOrdinaryCommitTruth
    testStockSimplifiedChinesePinyinBeforeBoundaryReturnCommitThenUndoTruth
    testStockSimplifiedChinesePinyinBeforeBoundaryResponderLossTruth
    testStockSimplifiedChinesePinyinAfterBoundaryCandidateCommitTruth
    testStockSimplifiedChinesePinyinAfterBoundaryCancelTruth
    testStockSimplifiedChinesePinyinAfterBoundaryOrdinaryCommitTruth
    testStockSimplifiedChinesePinyinAfterBoundaryReturnCommitThenUndoTruth
  )
  stock_test_languages=(
    japanese-romaji japanese-romaji japanese-romaji
    japanese-romaji japanese-romaji japanese-romaji
    japanese-romaji japanese-romaji japanese-romaji
    japanese-romaji japanese-romaji japanese-romaji
    simplified-chinese-pinyin simplified-chinese-pinyin
    simplified-chinese-pinyin simplified-chinese-pinyin
    simplified-chinese-pinyin simplified-chinese-pinyin
    simplified-chinese-pinyin simplified-chinese-pinyin
    simplified-chinese-pinyin simplified-chinese-pinyin
    simplified-chinese-pinyin simplified-chinese-pinyin
  )
  stock_test_decisions=(
    candidate-commit cancel ordinary-commit
    candidate-commit cancel ordinary-commit
    return-commit-then-undo responder-loss
    candidate-commit cancel ordinary-commit return-commit-then-undo
    candidate-commit cancel ordinary-commit
    candidate-commit cancel ordinary-commit
    return-commit-then-undo responder-loss
    candidate-commit cancel ordinary-commit return-commit-then-undo
  )
  if (( ${#stock_test_methods[@]} != 24 ||
        ${#stock_test_languages[@]} != 24 ||
        ${#stock_test_decisions[@]} != 24 )); then
    print -u2 -- "Complete IME stock matrix must contain exactly 24 rows"
    exit 70
  fi

  completed=0
  for repetition in $(seq 1 "$repetitions"); do
    row_index=1
    for test_method in "${stock_test_methods[@]}"; do
      row_language="${stock_test_languages[$row_index]}"
      decision="${stock_test_decisions[$row_index]}"
      observation="$output_directory/repetition-$repetition/$test_method"
      provisioning="$observation/provisioning"
      result="$observation/stock.xcresult"
      log="$observation/stock.log"
      summary="$observation/stock-summary.json"
      attachments="$observation/attachments"

      mkdir -p "$observation"
      require_no_overlapping_tests
      xcrun simctl shutdown "$simulator_udid" 2>/dev/null || true
      xcrun simctl erase "$simulator_udid"
      xcrun simctl boot "$simulator_udid"
      xcrun simctl bootstatus "$simulator_udid" -b
      Scripts/provision-ime-keyboards.sh "$simulator_udid" "$provisioning"
      require_no_overlapping_tests

      print -r -- \
        "START $row_language $test_method repetition $repetition"
      if ! xcodebuild test \
        -project InputDec.xcodeproj \
        -scheme InputDec \
        -destination "platform=iOS Simulator,id=$simulator_udid" \
        -parallel-testing-enabled NO \
        -collect-test-diagnostics never \
        "-only-testing:InputDecUITests/IDIMECompositionLifecycleUITests/$test_method" \
        -resultBundlePath "$result" >"$log" 2>&1; then
        tail -200 "$log"
        exit 65
      fi
      xcrun xcresulttool get test-results summary \
        --path "$result" --compact >"$summary"
      Scripts/validate-autocorrection-summary.py \
        "$summary" "$simulator_udid" \
        "$expected_os_version" "$expected_os_build"
      xcrun xcresulttool export attachments \
        --path "$result" --output-path "$attachments"
      python3 - "$attachments/manifest.json" "$decision" \
        "$test_method" "$observation/lifecycle.json" <<'PY'
import json
import pathlib
import sys

manifest_path, decision, method, output_path = sys.argv[1:]
manifest = json.loads(pathlib.Path(manifest_path).read_text())
if len(manifest) != 1 or not manifest[0]["testIdentifier"].endswith(method):
    raise SystemExit(f"unexpected test identity for {method}")
names = [
    item["suggestedHumanReadableName"]
    for item in manifest[0]["attachments"]
]
if decision == "candidate-commit":
    phases = [
        "baseline", "firstComposition", "updatedComposition",
        "candidateVisible", "decision", "immediate", "quiesced",
    ]
elif decision in {"cancel", "ordinary-commit"}:
    phases = [
        "baseline", "firstComposition", "updatedComposition",
        "decision", "immediate", "quiesced",
    ]
elif decision == "return-commit-then-undo":
    phases = [
        "baseline", "firstComposition", "updatedComposition",
        "decision", "immediate", "quiesced", "undo",
    ]
elif decision == "responder-loss":
    phases = [
        "baseline", "firstComposition", "updatedComposition",
        "decision", "postInterruption", "quiesced",
    ]
else:
    raise SystemExit(f"unsupported decision {decision}")
for phase in phases:
    screenshot = f"ime-composition-{phase}_"
    status = f"ime-composition-{phase}-status_"
    if sum(name.startswith(screenshot) for name in names) != 1:
        raise SystemExit(f"missing or duplicate screenshot for {phase}")
    if sum(name.startswith(status) for name in names) != 1:
        raise SystemExit(f"missing or duplicate status for {phase}")
pathlib.Path(output_path).write_text(json.dumps({
    "schema": 1,
    "testMethod": method,
    "decision": decision,
    "phases": phases,
    "attachmentCount": len(names),
}, indent=2, sort_keys=True) + "\n")
PY
      completed=$((completed + 1))
      row_index=$((row_index + 1))
      print -r -- \
        "PASS $row_language $test_method repetition $repetition"
    done
  done
  expected=$((24 * repetitions))
  if (( completed != expected )); then
    print -u2 -- \
      "Expected $expected complete stock rows, captured $completed"
    exit 70
  fi
  print -r -- \
    "Captured $completed independently erased complete IME stock rows in $output_directory"
  exit 0
fi

typeset -a attachment_directories
attachment_directories=()

for repetition in $(seq 1 "$repetitions"); do
  observation="$output_directory/observation-$repetition"
  provisioning="$observation/provisioning"
  result="$observation/stock.xcresult"
  log="$observation/stock.log"
  summary="$observation/stock-summary.json"
  attachments="$observation/attachments"

  mkdir -p "$observation"
  require_no_overlapping_tests
  xcrun simctl shutdown "$simulator_udid" 2>/dev/null || true
  xcrun simctl erase "$simulator_udid"
  xcrun simctl boot "$simulator_udid"
  xcrun simctl bootstatus "$simulator_udid" -b
  Scripts/provision-ime-keyboards.sh "$simulator_udid" "$provisioning"
  require_no_overlapping_tests

  print -r -- "START $language observation $repetition"
  if ! xcodebuild test \
    -project InputDec.xcodeproj \
    -scheme InputDec \
    -destination "platform=iOS Simulator,id=$simulator_udid" \
    -parallel-testing-enabled NO \
    -collect-test-diagnostics never \
    "-only-testing:InputDecUITests/IDIMECompositionLifecycleUITests/$test_method" \
    -resultBundlePath "$result" >"$log" 2>&1; then
    tail -200 "$log"
    exit 65
  fi
  xcrun xcresulttool get test-results summary \
    --path "$result" --compact >"$summary"
  Scripts/validate-autocorrection-summary.py \
    "$summary" "$simulator_udid" \
    "$expected_os_version" "$expected_os_build"
  xcrun xcresulttool export attachments \
    --path "$result" --output-path "$attachments"
  attachment_directories+=("$attachments")
  print -r -- "PASS $language observation $repetition"
done

python3 Scripts/ime_stock_truth.py \
  --language "$language" \
  --output "$output_directory/agreement.json" \
  "${attachment_directories[@]}"

print -r -- \
  "Captured and agreed $repetitions isolated $language stock observations in $output_directory"
