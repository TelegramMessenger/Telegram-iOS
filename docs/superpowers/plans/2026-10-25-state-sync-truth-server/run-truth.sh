#!/bin/bash
# Usage: bash docs/superpowers/plans/2026-10-25-state-sync-truth-server/run-truth.sh FIRST LAST OUTDIR [CHUNK]
#
# Runs the truth server's random sessions FIRST..LAST (TruthSessionTests.testRandomSessionsLong) in chunks of CHUNK
# seeds (default 250), one bazel test run per chunk, and collects every `TRUTH seed=` line into OUTDIR/results.txt and
# each chunk's summary into OUTDIR/summary.txt; each failing seed's whole report goes to OUTDIR/seed-<n>.txt. Run run-make.sh test once first: it resolves the configuration this
# bazel command line relies on. Make.py cannot pass a test environment, so this calls bazel with the command line
# Make.py test uses (build-input/state-sync-test.log) plus --test_env and --test_filter.
set -u
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
cd "$ROOT" || exit 1
FIRST="$1"; LAST="$2"; OUT="$3"; CHUNK="${4:-250}"
mkdir -p "$OUT"
: > "$OUT/results.txt"
: > "$OUT/summary.txt"
STATUS=0
START=$FIRST
while [ "$START" -le "$LAST" ]; do
    END=$((START + CHUNK - 1))
    if [ "$END" -gt "$LAST" ]; then END=$LAST; fi
    LOG="$OUT/chunk-$START-$END.log"
    "$ROOT/build-input/bazel-9.2.0-darwin-arm64" test --cache_test_results=no --test_output=errors \
        //submodules/TelegramCore:TelegramCoreTests --announce_rc --features=swift.use_global_module_cache \
        --verbose_failures --remote_cache_async --define=buildNumber=10000 --disk_cache=/Users/isaac/telegram-bazel-cache \
        -c dbg --ios_multi_cpus=sim_arm64 --watchos_cpus=arm64_32 \
        '--@build_bazel_rules_swift//swift:copt="-j"' '--@build_bazel_rules_swift//swift:copt="16"' \
        --test_env=TRUTH_SEEDS="$START-$END" --test_env=TRUTH_REPORT_DIR="$OUT" --test_env=TRUTH_SHAPE="${TRUTH_SHAPE:-small}" --test_env=TRUTH_TIMING="${TRUTH_TIMING:-instant}" --test_timeout=3600 \
        --test_filter=TruthSessionTests/testRandomSessionsLong > "$LOG" 2>&1
    CHUNK_STATUS=$?
    TESTLOG="$ROOT/bazel-testlogs/submodules/TelegramCore/TelegramCoreTests/test.log"
    cp "$TESTLOG" "$OUT/chunk-$START-$END.test.log" 2>/dev/null
    grep -o "TRUTH seed=.*" "$TESTLOG" >> "$OUT/results.txt"
    SUMMARY=$(grep -o "TRUTH summary.*" "$TESTLOG" | tail -1)
    echo "$START-$END exit=$CHUNK_STATUS ${SUMMARY:-no summary}" | tee -a "$OUT/summary.txt"
    if [ "$CHUNK_STATUS" -ne 0 ]; then STATUS=1; fi
    START=$((END + 1))
done
echo "seeds: $(wc -l < "$OUT/results.txt"), ok: $(grep -c 'result=ok' "$OUT/results.txt")"
exit $STATUS
