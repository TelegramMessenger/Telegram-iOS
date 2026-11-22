#!/bin/zsh

set -euo pipefail

readonly root="${0:A:h:h}"
readonly pinned_udid="FA6F7462-AA97-42FE-9E57-8DA0593CE756"
udid=""

function usage() {
  print -u2 -- "Usage: $0 --udid UDID -- command [arguments ...]"
}

if (( $# < 4 )) || [[ "$1" != "--udid" || "$3" != "--" ]]; then
  usage
  exit 64
fi
udid="$2"
shift 3

[[ "$udid" == "$pinned_udid" ]] || {
  print -u2 -- "Refusing non-K3 simulator: $udid"
  exit 64
}
(( $# > 0 )) || {
  usage
  exit 64
}

readonly lock_root="${INPUTDEC_XCTEST_LOCK_ROOT:-${TMPDIR:-/tmp}}"
readonly lock_directory="$lock_root/inputdec-xctest-${udid}.lock"
readonly owner_file="$lock_directory/owner-pid"

function live_pid() {
  local pid="$1"
  [[ "$pid" == <-> ]] && kill -0 "$pid" 2>/dev/null
}

if [[ -n "${INPUTDEC_XCTEST_LOCK_OWNER_PID:-}" ]]; then
  inherited_owner="$INPUTDEC_XCTEST_LOCK_OWNER_PID"
  recorded_owner=""
  [[ -f "$owner_file" ]] &&
    recorded_owner="$(<"$owner_file")"
  if [[ "$recorded_owner" != "$inherited_owner" ]] ||
     ! live_pid "$inherited_owner"; then
    print -u2 -- "Refusing forged or stale XCTest lock ownership"
    exit 75
  fi
  "$@"
  exit $?
fi

overlap="$(ps -axo pid=,command= |
  rg 'xcodebuild .*test|/xctest|XCTest' |
  rg "$udid" |
  rg 'InputDec' |
  rg -v 'with-inputdec-simulator-test-lock.sh' |
  rg -v 'rg ' || true)"
if [[ -n "$overlap" ]]; then
  print -r -- "$overlap"
  print -u2 -- "Refusing overlapping repository XCTest run"
  exit 75
fi

mkdir -p "$lock_root"
while ! mkdir "$lock_directory" 2>/dev/null; do
  recorded_owner=""
  [[ -f "$owner_file" ]] &&
    recorded_owner="$(<"$owner_file")"
  if live_pid "$recorded_owner"; then
    print -u2 -- "Refusing live XCTest lock owner: $recorded_owner"
    exit 75
  fi
  rm -rf "$lock_directory"
done
print -r -- "$$" >"$owner_file"

child_pid=""
function cleanup_lock() {
  local recorded_owner=""
  [[ -f "$owner_file" ]] &&
    recorded_owner="$(<"$owner_file")"
  if [[ "$recorded_owner" == "$$" ]]; then
    rm -rf "$lock_directory"
  fi
}

function terminate_child() {
  if [[ -n "$child_pid" ]] && live_pid "$child_pid"; then
    kill -TERM "$child_pid" 2>/dev/null || true
  fi
  cleanup_lock
  exit 143
}

trap cleanup_lock EXIT
trap terminate_child INT TERM
export INPUTDEC_XCTEST_LOCK_OWNER_PID="$$"

set +e
"$@" &
child_pid="$!"
wait "$child_pid"
child_status="$?"
child_pid=""
set -e
exit "$child_status"
