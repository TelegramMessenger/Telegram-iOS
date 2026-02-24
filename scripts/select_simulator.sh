#!/bin/bash

set -e

WORKSPACE_ROOT=$(pwd)
OUTPUT_FILE=${WORKSPACE_ROOT}/.bsp/skbsp_generated/simulator_info.txt

SIMULATORS=$(xcrun simctl list devices available -j | jq -r '
  .devices | to_entries[] |
  .key as $runtime |
  .value[] |
  ($runtime | split("SimRuntime.")[1] | split("-") | "\(.[0]) \(.[1]).\(.[2])") as $version |
  "\(.name) (\($version)) - \(.udid)"
' | sort)

if [ -z "$SIMULATORS" ]; then
  echo "error: No available simulators found."
  exit 1
fi

if ! command -v fzf &> /dev/null; then
  echo "error: You need \`fzf\` to run this script. You can install it with 'brew install fzf'."
  exit 1
fi

SELECTED=$(echo "$SIMULATORS" | fzf --height=20 --reverse --prompt="Select the simulator you'd like to use: ")

if [ -z "$SELECTED" ]; then
  echo "error: No simulator selected."
  exit 1
fi

UUID=$(echo "$SELECTED" | awk -F' - ' '{print $2}')

mkdir -p "$(dirname "$OUTPUT_FILE")" || true
echo -n "$UUID" > "$OUTPUT_FILE"

echo "Selected simulator: $SELECTED"
echo "UUID ($UUID) successfully written to: $OUTPUT_FILE"
echo "The selected simulator will now be used for your future builds."
