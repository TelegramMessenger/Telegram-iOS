#!/bin/bash
# Usage: bash docs/superpowers/plans/2026-10-14-state-sync-foundation/run-loop.sh FIRST LAST OUTDIR
#
# Runs TelegramCoreTests (via run-make.sh test) once for each N in FIRST..LAST, keeping each run's logs in
# OUTDIR/run-N/, and stops after the first run that fails. A run passes only if Make.py exited 0 AND the suite's FINAL
# "Executed N tests" line (the last one in the log, the total) reports 0 failures. Per-suite "Executed ... with 0
# failures" lines must not count: an earlier version grepped any such line and missed a real failure (2026-10-16).
# Use it for the stage-end "20 runs in a row" check: every StateSync class must pass 20 consecutive runs; a stall is a
# regression.
set -u
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
FIRST="$1"; LAST="$2"; OUTDIR="$3"
for N in $(seq "$FIRST" "$LAST"); do
    OUT="$OUTDIR/run-$N"
    mkdir -p "$OUT"
    START=$(date +%s)
    bash "$ROOT/docs/superpowers/plans/2026-10-14-state-sync-foundation/run-make.sh" test > "$OUT/summary.txt" 2>&1
    STATUS=$?
    END=$(date +%s)
    TESTLOG="$(ls -t "$ROOT"/bazel-out/*/testlogs/submodules/TelegramCore/TelegramCoreTests/test.log 2>/dev/null | head -1)"
    [ -n "$TESTLOG" ] && cp "$TESTLOG" "$OUT/test.log"
    TOTAL=$(grep -E "Executed [0-9]+ tests" "$OUT/test.log" 2>/dev/null | tail -1)
    echo "status=$STATUS seconds=$((END-START)) total=$TOTAL" >> "$OUT/summary.txt"
    if [ "$STATUS" -eq 0 ] && echo "$TOTAL" | grep -q "with 0 failures"; then
        echo "run $N: pass ($TOTAL)"
    else
        echo "run $N: FAIL or incomplete ($TOTAL)"
        grep -E "error: -\[|failed \(" "$OUT/test.log" 2>/dev/null | head -20
        exit 1
    fi
done
