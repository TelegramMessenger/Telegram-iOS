#!/bin/zsh
set -euo pipefail

root="${0:A:h:h}"
cd "$root"

simulator_udid="${1:-FA6F7462-AA97-42FE-9E57-8DA0593CE756}"
output_root="${2:-.inline-prediction-task6-complete-matrix}"
expected_os_version="${3:-26.5}"
expected_os_build="${4:-23F73}"
resume_mode="${5:-}"
readonly prediction_model_readiness_delay=20
readonly native_offer_attempt_limit=20
methods=(
  InteriorAccept
  InteriorDismissThenType
  InteriorAcceptThenDelete
  BeforeBoundaryAccept
  BeforeBoundaryDismissThenType
  BeforeBoundaryAcceptThenDelete
  AfterBoundaryAccept
  AfterBoundaryDismissThenType
  AfterBoundaryAcceptThenDelete
)

refuse_xctest_overlap() {
  local overlap
  overlap="$(ps -axo pid=,command= |
    rg 'xcodebuild .*test|/xctest|XCTest' |
    rg -v 'rg ' || true)"
  if [[ -n "$overlap" ]]; then
    print -r -- "$overlap"
    echo "Refusing overlapping XCTest run"
    exit 75
  fi
}

refuse_existing_path() {
  local path="$1"
  local description="$2"
  if [[ -e "$path" ]]; then
    echo "Refusing to replace preserved $description: $path"
    exit 73
  fi
}

refuse_existing_result_bundle() {
  local result="$1"
  if [[ -e "$result" ]]; then
    echo "Refusing to replace preserved result bundle: $result"
    exit 73
  fi
}

run_fresh_row() {
  local host="$1"
  local method="$2"
  local pair="$3"
  local attempt
  local result
  local selector
  local log
  local summary
  local previous_log
  local preserve_boot
  successful_result=""

  local existing_summaries
  existing_summaries=("$pair/${host:l}-attempt-"*-summary.json(N))
  if (( ${#existing_summaries} > 0 )); then
    successful_result="${existing_summaries[1]%-summary.json}.xcresult"
    echo "RESUME_PASS host=$host method=$method result=$successful_result"
    return 0
  fi

  if [[ "$host" == Stock ]]; then
    selector="testStock${method}Truth"
  else
    selector="testCustom${method}MatchesStock"
  fi

  # The system language model can occasionally decline to publish any inline
  # offer after a freshly erased boot. Retry only that explicit environmental
  # condition; every attempt remains preserved and every other failure remains
  # immediately fatal.
  for attempt in {1..$native_offer_attempt_limit}; do
    result="$pair/${host:l}-attempt-${attempt}.xcresult"
    log="${result%.xcresult}.log"
    summary="${result%.xcresult}-summary.json"

    refuse_xctest_overlap
    if [[ -e "$result" || -e "$log" ]]; then
      if [[ "$resume_mode" == "--resume" && -e "$result" && -e "$log" ]] &&
          rg -Fq "Expected native inline prediction was absent" "$log"; then
        echo "RESUME_NATIVE_OFFER_ABSENT host=$host method=$method attempt=$attempt"
        continue
      fi
      if [[ "$resume_mode" == "--resume" && -e "$result" && -e "$log" ]] &&
          rg -Fq "not all contents have been imported" "$log"; then
        echo "RESUME_INTERRUPTED_ATTEMPT host=$host method=$method attempt=$attempt"
        continue
      fi
      refuse_existing_result_bundle "$result"
      refuse_existing_path "$log" "test log"
    fi
    refuse_existing_path "$summary" "compact summary"

    preserve_boot=0
    if [[ "$attempt" -gt 1 ]]; then
      previous_log="$pair/${host:l}-attempt-$(( attempt - 1 )).log"
      if [[ -e "$previous_log" ]] &&
          (rg -Fq "Expected native inline prediction was absent" "$previous_log" ||
           rg -Fq "not all contents have been imported" "$previous_log"); then
        preserve_boot=1
      fi
    fi
    if [[ "$preserve_boot" -eq 1 ]]; then
      # The failed target interaction itself warms UIKit's system language
      # model. Keep that erased host alive for the classified no-offer retry,
      # matching the keyboard-service state used by the batched authority run.
      echo "RETRY_PRESERVING_BOOT host=$host method=$method attempt=$attempt"
    else
      xcrun simctl shutdown "$simulator_udid" 2>/dev/null || true
      xcrun simctl erase "$simulator_udid"
      xcrun simctl boot "$simulator_udid"
      xcrun simctl bootstatus "$simulator_udid" -b
      # bootstatus completes before the freshly erased simulator's on-device
      # language model consistently begins publishing inline predictions.
      sleep "$prediction_model_readiness_delay"
    fi

    echo "START host=$host method=$method attempt=$attempt result=$result"
    if xcodebuild test \
      -project InputDec.xcodeproj \
      -scheme InputDec \
      -destination "platform=iOS Simulator,id=$simulator_udid" \
      -parallel-testing-enabled NO \
      -collect-test-diagnostics never \
      -resultBundlePath "$result" \
      -only-testing:"InputDecUITests/IDInlinePredictionLifecycleUITests/$selector" \
      >"$log" 2>&1; then
      xcrun xcresulttool get test-results summary \
        --path "$result" --compact > "$summary"
      Scripts/validate-autocorrection-summary.py \
        "$summary" "$simulator_udid" "$expected_os_version" "$expected_os_build"
      successful_result="$result"
      echo "PASS host=$host method=$method attempt=$attempt result=$result"
      return 0
    fi

    if rg -Fq "Expected native inline prediction was absent" "$log"; then
      echo "RETRY_NATIVE_OFFER_ABSENT host=$host method=$method attempt=$attempt"
      if [[ "$attempt" -lt "$native_offer_attempt_limit" ]]; then
        continue
      fi
    fi

    tail -200 "$log"
    return 65
  done
}

refuse_xctest_overlap
if [[ "$resume_mode" != "--resume" ]]; then
  refuse_existing_path "$output_root" "matrix output root"
fi
mkdir -p "$output_root"

for repetition in 1 2; do
  for order in StockThenCustom CustomThenStock; do
    for method in $methods; do
      pair="$output_root/repeat-${repetition}-${order}-${method}"
      if [[ "$resume_mode" == "--resume" && -e "$pair/parity.json" ]]; then
        echo "RESUME_PARITY repetition=$repetition order=$order method=$method"
        continue
      fi
      if [[ "$resume_mode" != "--resume" ]]; then
        refuse_existing_path "$pair" "pair directory"
      fi
      mkdir -p "$pair"

      if [[ "$order" == StockThenCustom ]]; then
        hosts=(Stock Custom)
      else
        hosts=(Custom Stock)
      fi

      stock_result=""
      custom_result=""
      for host in $hosts; do
        run_fresh_row "$host" "$method" "$pair"
        if [[ "$host" == Stock ]]; then
          stock_result="$successful_result"
        else
          custom_result="$successful_result"
        fi
      done

      comparator_log="$pair/comparator.log"
      refuse_existing_path "$comparator_log" "comparator log"
      if ! Scripts/compare-inline-prediction-results.py \
        "$stock_result" "$custom_result" "$pair" \
        >"$comparator_log" 2>&1; then
        cat "$comparator_log"
        exit 65
      fi
      echo "PARITY repetition=$repetition order=$order method=$method"
    done
  done
done
