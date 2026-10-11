#!/bin/zsh
set -euo pipefail

root="${0:A:h:h}"
cd "$root"

if [[ "$#" -ne 2 ]]; then
  echo "Usage: $0 <pinned-simulator-udid> <fresh-evidence-directory>"
  exit 64
fi

udid="$1"
output="$2"
readonly pinned_udid="FA6F7462-AA97-42FE-9E57-8DA0593CE756"
readonly contract="UITests/Fixtures/ime-keyboard-modes-ios26.5-v1.json"

if [[ "$udid" != "$pinned_udid" ]]; then
  echo "Refusing non-K3 simulator: $udid"
  exit 64
fi

overlap="$(ps -axo pid=,command= |
  rg 'xcodebuild .*test|/xctest|XCTest' |
  rg "$pinned_udid" |
  rg -v 'rg ' || true)"
if [[ -n "$overlap" ]]; then
  print -r -- "$overlap"
  echo "Refusing overlapping XCTest run"
  exit 75
fi

if [[ -e "$output" ]]; then
  echo "Refusing to replace preserved provisioning evidence: $output"
  exit 73
fi
[[ ! -e "$output" ]]

python3 Scripts/ime_keyboard_contract.py validate \
  --contract "$contract" >/dev/null
python3 Scripts/ime_keyboard_contract.py provision \
  --contract "$contract" \
  --udid "$udid" \
  --output "$output"
