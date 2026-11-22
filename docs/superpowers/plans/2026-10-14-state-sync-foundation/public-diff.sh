#!/bin/bash
# Usage: bash docs/superpowers/plans/2026-10-14-state-sync-foundation/public-diff.sh BASE HEAD OUTDIR
#
# Diffs the multiset of public/open declaration lines in TelegramCore's Sources between two commits (the stage-end
# "public API unchanged" check; a word "open" in a doc comment shows up as a false positive). Uses `git grep -P`:
# git grep's -E ignores \s and \b, and an earlier version of this check matched nothing and passed vacuously.
# A stronger check, used by the stage-4 checker: dump each build's TelegramCore.swiftmodule with
# `swift-api-digester -dump-sdk` and compare the dumps.
set -u
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
cd "$ROOT" || exit 1
BASE="$1"; HEAD_REV="$2"; OUT="$3"
mkdir -p "$OUT"
for REV in "$BASE" "$HEAD_REV"; do
    git grep -h -P '^\s*(@[A-Za-z_]+(\([^)]*\))?\s+)*(public|open)\s' "$REV" -- submodules/TelegramCore/Sources \
        | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | sort > "$OUT/$REV.txt"
    echo "$REV: $(wc -l < "$OUT/$REV.txt") public lines"
done
if diff "$OUT/$BASE.txt" "$OUT/$HEAD_REV.txt" > "$OUT/diff.txt"; then
    echo "public declarations identical"
else
    echo "DIFFERENCES:"; cat "$OUT/diff.txt"
fi
