#!/bin/zsh

set -euo pipefail

readonly root="${0:A:h:h}"
cd "$root"
readonly pinned_udid="FA6F7462-AA97-42FE-9E57-8DA0593CE756"
readonly keyboard_service="user/501/com.apple.TextInput.kbd"

udid=""
output=""
while (( $# > 0 )); do
  case "$1" in
    --udid) udid="$2"; shift 2 ;;
    --output) output="$2"; shift 2 ;;
    *) print -u2 -- "Usage: $0 --udid UDID --output PATH"; exit 64 ;;
  esac
done
[[ "$udid" == "$pinned_udid" && -n "$output" ]] || exit 64
[[ -n "${INPUTDEC_XCTEST_LOCK_OWNER_PID:-}" ]] || {
  print -u2 -- "Refusing baseline capture without the global XCTest lock"
  exit 75
}

output="${output:A}"
[[ ! -e "$output" ]] || {
  print -u2 -- "Baseline output already exists: $output"
  exit 73
}
mkdir -p "${output:h}"
readonly device_root="$HOME/Library/Developer/CoreSimulator/Devices/$udid/data"
readonly provisioning="${output:h}/inline-keyboard-provisioning-v1"
readonly identity="${output:h}/.inline-keyboard-identity.partial-$$.json"

xcrun simctl shutdown "$udid" 2>/dev/null || true
xcrun simctl erase "$udid"
xcrun simctl boot "$udid"
xcrun simctl bootstatus "$udid" -b
xcrun simctl spawn "$udid" defaults write NSGlobalDomain AppleLocale en_US
xcrun simctl spawn "$udid" defaults write NSGlobalDomain \
  AppleLanguages -array en-US
Scripts/provision-english-us-keyboard.sh "$udid" "$provisioning"

python3 - "$provisioning/summary.json" "$identity" "$udid" <<'PY'
import json
import pathlib
import sys
summary = json.loads(pathlib.Path(sys.argv[1]).read_text())
identity = {
    "schema": 1,
    "udid": sys.argv[3],
    "runtime": {"osVersion": "26.5", "osBuild": "23F73"},
    "locale": "en_US",
    "inputModes": summary["inventory"],
    "manifestFormat": 1,
}
pathlib.Path(sys.argv[2]).write_text(
    json.dumps(identity, indent=2, sort_keys=True) + "\n"
)
PY

xcrun simctl terminate "$udid" com.inputdec.demo 2>/dev/null || true
xcrun simctl terminate "$udid" com.inputdec.stockoracle 2>/dev/null || true
xcrun simctl spawn "$udid" launchctl disable "$keyboard_service"
restart_needed=1
function restart_keyboard_service() {
  (( restart_needed == 0 )) || {
    xcrun simctl spawn "$udid" launchctl enable "$keyboard_service"
    xcrun simctl spawn "$udid" launchctl kickstart -k "$keyboard_service"
    restart_needed=0
  }
}
trap 'restart_keyboard_service; rm -f "$identity"' EXIT
trap 'restart_keyboard_service; rm -f "$identity"; trap - EXIT; exit 130' \
  INT TERM
xcrun simctl spawn "$udid" launchctl kill SIGKILL "$keyboard_service"
python3 Scripts/text_input_keyboard_snapshot.py capture \
  --device-root "$device_root" --identity "$identity" --output "$output"
chmod -R a-w "$output"
restart_keyboard_service
rm -f "$identity"
trap - EXIT INT TERM
print -r -- "PASS inline keyboard baseline=$output"
