#!/bin/zsh
set -euo pipefail

root="${0:A:h:h}"
cd "$root"

if [[ "$#" -lt 2 || "$#" -gt 3 ||
      ("$#" -eq 3 && "$3" != "--verify") ]]; then
  echo "Usage: $0 <pinned-simulator-udid> <fresh-evidence-directory> [--verify]"
  exit 64
fi

udid="$1"
output="$2"
readonly pinned_udid="FA6F7462-AA97-42FE-9E57-8DA0593CE756"
readonly identifier="en_US@hw=Automatic"

[[ "$udid" == "$pinned_udid" ]] || {
  echo "Refusing non-K3 simulator: $udid"
  exit 64
}
[[ ! -e "$output" ]] || {
  echo "Refusing to replace preserved provisioning evidence: $output"
  exit 73
}

mkdir -p "$output"
os_version="$(xcrun simctl getenv "$udid" SIMULATOR_RUNTIME_VERSION)"
os_build="$(xcrun simctl getenv "$udid" SIMULATOR_RUNTIME_BUILD_VERSION)"
[[ "$os_version" == "26.5" && "$os_build" == "23F73" ]] || {
  echo "Simulator runtime is not pinned iOS 26.5 (23F73)"
  exit 64
}

function write_profile() {
  xcrun simctl spawn "$udid" defaults write NSGlobalDomain \
    AppleLocale en_US
  xcrun simctl spawn "$udid" defaults write NSGlobalDomain \
    AppleLanguages -array en-US
  xcrun simctl spawn "$udid" defaults write NSGlobalDomain \
    AppleKeyboards -array "$identifier"
  xcrun simctl spawn "$udid" defaults write NSGlobalDomain \
    AppleKeyboardsExpanded -bool YES
}

write_profile
xcrun simctl shutdown "$udid"
xcrun simctl boot "$udid"
xcrun simctl bootstatus "$udid" -b
rebooted_os_version="$(xcrun simctl getenv "$udid" SIMULATOR_RUNTIME_VERSION)"
rebooted_os_build="$(xcrun simctl getenv "$udid" SIMULATOR_RUNTIME_BUILD_VERSION)"
[[ "$rebooted_os_version" == "26.5" && "$rebooted_os_build" == "23F73" ]] || {
  echo "Rebooted simulator runtime is not pinned iOS 26.5 (23F73)"
  exit 64
}
write_profile
xcrun simctl spawn "$udid" notifyutil -p \
  AppleKeyboardsPreferencesChangedNotification
xcrun simctl spawn "$udid" launchctl kickstart -k \
  user/501/com.apple.TextInput.kbd
xcrun simctl spawn "$udid" defaults read NSGlobalDomain AppleKeyboards \
  >"$output/inventory.txt"
if [[ "${3:-}" == "--verify" ]]; then
  python3 Scripts/english_us_keyboard_profile.py verify \
    --udid "$udid" \
    --output "$output/verification" >/dev/null
fi

python3 - "$output/summary.json" "$udid" "$identifier" <<'PY'
import json
import pathlib
import sys

path, udid, identifier = sys.argv[1:]
payload = {
    "commandCount": 13,
    "inventory": [identifier],
    "primaryLanguages": ["en-US"],
    "runtime": {"osVersion": "26.5", "osBuild": "23F73"},
    "schema": 1,
    "udid": udid,
}
pathlib.Path(path).write_text(
    json.dumps(payload, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
PY
