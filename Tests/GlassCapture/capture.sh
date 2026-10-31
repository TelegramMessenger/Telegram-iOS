#!/bin/bash
# capture.sh <out dir> <label> [launch arguments...]: launch the GlassCapture harness on a booted simulator ($SIM, a
# udid), wait for its manifest, screenshot, and keep both as <out dir>/<label>.{png,json}. The harness must be installed
# (README.md). Example: SIM=<udid> Tests/GlassCapture/capture.sh /tmp/glass light-panel-FFFFFF -page FFFFFF -dark 0
set -e
UDID="${SIM:?set SIM to the simulator's udid}"
ID=org.telegram.GlassCapture
OUT="$1"; label="$2"; shift 2
mkdir -p "$OUT"
DATA=$(xcrun simctl get_app_container "$UDID" $ID data)
xcrun simctl terminate "$UDID" $ID 2>/dev/null || true
rm -f "$DATA/Documents/manifest.json"
xcrun simctl launch "$UDID" $ID -label "$label" "$@" >/dev/null
for i in $(seq 1 40); do
    [ -f "$DATA/Documents/manifest.json" ] && break
    sleep 0.25
done
[ -f "$DATA/Documents/manifest.json" ] || { echo "no manifest for $label"; exit 1; }
sleep 0.5
xcrun simctl io "$UDID" screenshot "$OUT/$label.png" >/dev/null 2>&1
cp "$DATA/Documents/manifest.json" "$OUT/$label.json"
echo "$label"
