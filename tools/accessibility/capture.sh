#!/bin/bash
# Usage: capture.sh <udid> <screen-id>
# Writes screen.png, tree.json and report.txt under build/accessibility/<screen-id>/.
set -euo pipefail
[ $# -eq 2 ] || { echo "usage: $0 <udid> <screen-id>" >&2; exit 2; }
UDID=$1; ID=$2
AXE=${AXE:-$HOME/.local/opt/axe/axe}
ROOT=$(git rev-parse --show-toplevel)
OUT="$ROOT/build/accessibility/$ID"
mkdir -p "$OUT"
xcrun simctl io "$UDID" screenshot "$OUT/screen.png" >/dev/null 2>&1
"$AXE" describe-ui --udid "$UDID" > "$OUT/tree.json"
python3 "$ROOT/tools/accessibility/axaudit.py" "$OUT/tree.json" > "$OUT/report.txt"
echo "$OUT"
grep '^FLAG ' "$OUT/report.txt" || echo "no flags"
