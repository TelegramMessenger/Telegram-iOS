#!/bin/zsh
# Films one keyboard scenario of the reference app and saves its probe (2026-10-14; see the keyboard RE note).
# Usage: [UDID=…] [OUT=dir] [REQUIRE_KB=1] keyboard_run.sh <name> <launch args…> -- "<shell command>" ["<shell command>" …]
# The commands run in order once the app has launched and recording has started, e.g.
#   keyboard_run.sh push -textField 1 -probe 1 -focusAt 0 -- "axe touch -x 201 -y 358 --down --up --delay 0.05 --udid \$UDID"
# REQUIRE_KB=1 relaunches (up to 4 times) until the probe has seen keyboardWillShow: the simulator sometimes comes up in
# hardware-keyboard mode. Writes <OUT>/<name>.mp4 and <OUT>/<name>.probe.txt; read the probe with keyboard_table.py.
U=${UDID:-E643A78E-DB62-4DA4-9F54-BD0836F434AF}
OUT=${OUT:-.}
NAME=$1; shift
ARGS=()
while [ "$1" != "--" ] && [ -n "$1" ]; do ARGS+=("$1"); shift; done
shift
for attempt in 1 2 3 4; do
  xcrun simctl terminate $U org.telegram.NativeNavigationReference 2>/dev/null
  xcrun simctl launch $U org.telegram.NativeNavigationReference "${ARGS[@]}" >/dev/null
  sleep 2.5
  [ -z "$REQUIRE_KB" ] && break
  D=$(xcrun simctl get_app_container $U org.telegram.NativeNavigationReference data)
  grep -q "MARK keyboard willShow" $D/tmp/probe.txt && break
  echo "no keyboard on attempt $attempt"
done
xcrun simctl io $U recordVideo --codec=h264 --force $OUT/$NAME.mp4 >/dev/null 2>&1 &
REC=$!
sleep 1.0
for cmd in "$@"; do
  UDID=$U eval "$cmd"
done
sleep 2.0
kill -INT $REC; wait $REC 2>/dev/null
sleep 1.2
D=$(xcrun simctl get_app_container $U org.telegram.NativeNavigationReference data)
cp $D/tmp/probe.txt $OUT/$NAME.probe.txt
echo "done $NAME"
