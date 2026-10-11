#!/bin/bash
# Runs the InputDec test suite on a simulator, with the four traps that cost a working session
# on 2026-08-28 designed out rather than remembered.
#
#   ./Scripts/idtest.sh                                 whole suite
#   ./Scripts/idtest.sh InputDecTests/IDFooTests        one class
#   DEVICE=<udid> ./Scripts/idtest.sh                   another simulator
#   STALL=180 ./Scripts/idtest.sh                       longer stall tolerance
#
# THE FOUR TRAPS. Each produced a confident wrong reading, not an error:
#
# 1. `simctl diagnose`. On a FAILING run, xcodebuild launches `simctl diagnose --timeout=600`,
#    which blocks for up to TEN MINUTES after the tests have already finished, emitting nothing.
#    It reads exactly like a hung compile. Three runs were lost to this before it was recognised.
#    `-collect-test-diagnostics never` is therefore not optional here.
#
# 2. `| tail -N` at the end of a filter pipeline. `tail` cannot stream — it must wait for EOF — so
#    the output file stays EMPTY for the entire run and there is no way to tell a slow suite from a
#    hung one. This script writes the full log to a file AND filters with --line-buffered, never
#    through `tail`.
#
# 3. `xcodebuild | grep` exits with GREP's status. A run with failing tests exits 0. Every "did it
#    pass" check built on that exit code is answering a different question. This script never pipes
#    xcodebuild at all -- it redirects to a log and waits on the build PID, so the exit is real.
#    Validated both ways: a passing class exits 0, a planted XCTFail exits 65.
#
# 4. A wedged simulator pasteboard. `com.apple.UIKit.pasteboard.cache-queue` blocks the test host
#    indefinitely at 0% CPU, taking the whole suite with it — seen three times in one day, twice in
#    tests and once in a running app. The watchdog below catches it, and anything else that hangs,
#    without needing to know the cause in advance.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

# By UDID, never by name: a bare name like "iPhone 17 Pro" collides with several simulators and
# xcodebuild answers by enumerating every device with a deployment-target error, which reads as an
# SDK problem rather than a bad destination.
DEVICE="${DEVICE:-03A7DA9C-1832-49B8-9858-2F54F2FB5A04}"   # iPhone 18 Pro K1 (the K-sims were
# re-created by the Xcode 27 update, 2026-09-15, which removed every simulator: new UDIDs.)
STALL="${STALL:-240}"                                       # seconds of SILENT + IDLE before suspecting a hang
FILTER=""
[ -n "${1:-}" ] && FILTER="-only-testing:$1"
# SKIP="ClassA ClassB" -- exclude classes. Needed because some classes exercise the simulator
# pasteboard, and on a host whose pasteboard XPC service is unhealthy they block the whole run.
# That is an environment fault, not a code fault: they hang identically on a pristine checkout and
# a freshly erased simulator.
for skip in ${SKIP:-}; do FILTER="$FILTER -skip-testing:InputDecTests/$skip"; done

LOG="${LOG:-/tmp/idtest-$$.log}"
: > "$LOG"

# PRE-FLIGHT: retire stale pasteboard daemons.
#
# `com.apple.UIKit.pasteboard.cache-queue` blocking the test host is the single most common cause of
# a hung run here -- four occurrences on 2026-08-28, in tests and in a running app. The trigger is a
# long-lived `dtpasteboardd` that has wedged; a fresh one respawns on demand within seconds, so
# retiring an old one is cheap and non-destructive.
#
# DETECTING it is the part that does not work. `xcrun simctl pbpaste` was tried as a probe and gives
# a FALSE ALL-CLEAR: it answered in one second while the in-simulator pasteboard was wedged solid,
# because simctl reaches the pasteboard by a different path than an app's `UIPasteboard.general`.
# So this heals unconditionally rather than probing first.
#
# SIGTERM IS IGNORED by this daemon -- a plain `kill` looked like it worked and left the wedged
# process running for another twenty minutes. It must be SIGKILL.
# WHEN THE HANG COMES BACK, ERASE THE SIMULATOR. Retiring daemons does NOT fix it: a freshly
# spawned dtpasteboardd wedged within minutes on a simulator whose state had gone bad, while a
# brand-new simulator on the SAME runtime passed the identical test in 0.3s. `xcrun simctl erase`
# on the device below is the remedy; the daemon sweep here is only cheap insurance.
#
# And do NOT "verify the fix" on a different K-sim without checking its runtime -- K2 is iOS 27.0
# while the engine is iOS 26.5-only, so a green run there confounds device state with OS version
# and proves nothing. Compare against a fresh simulator on the SAME runtime.
STALE_MINUTES="${STALE_MINUTES:-30}"
for pid in $(pgrep -x dtpasteboardd 2>/dev/null); do
    secs=$(ps -o etime= -p "$pid" 2>/dev/null | awk -F'[:-]' '{
        n = NF; s = 0; m = 1
        for (i = n; i >= 1; i--) { s += $i * m; m = (m == 1) ? 60 : (m == 60 ? 3600 : 86400) }
        print s
    }')
    if [ "${secs:-0}" -gt $((STALE_MINUTES * 60)) ]; then
        echo "PRE-FLIGHT: retiring stale dtpasteboardd pid $pid (age ${secs}s); it respawns on demand."
        kill -9 "$pid" 2>/dev/null
    fi
done

xcodebuild test \
    -parallel-testing-enabled NO \
    -collect-test-diagnostics never \
    -project InputDec.xcodeproj -scheme InputDec \
    -destination "platform=iOS Simulator,id=$DEVICE" \
    -derivedDataPath .derivedData-idtest \
    $FILTER > "$LOG" 2>&1 &
BUILD_PID=$!

# Watchdog. Cause-agnostic on purpose: it asks "has this stopped making progress", not "is it stuck
# on the pasteboard". When it fires it SAMPLES the stalled process and prints the blocking dispatch
# queues, which is what turns "it hangs sometimes" into a named cause in one run.
# The test HOST process running inside the simulator -- the thing that actually blocks.
runner_pid() {
    pgrep -f "CoreSimulator/Devices/$DEVICE/data/Containers/Bundle/App" 2>/dev/null | head -1
}

(
    last_size=0
    stalled=0
    while kill -0 "$BUILD_PID" 2>/dev/null; do
        sleep 15
        size=$(wc -c < "$LOG" 2>/dev/null || echo 0)
        if [ "$size" -ne "$last_size" ]; then
            last_size=$size
            stalled=0
            continue
        fi
        # SILENCE IS NOT A HANG. A long differential test emits nothing for minutes while working
        # hard -- the first version of this watchdog checked only log growth and killed a perfectly
        # healthy suite mid-test. The discriminator is CPU: a wedged run sits at ~0% (blocked on a
        # dispatch queue), a slow one does not. Require BOTH before firing.
        pid=$(runner_pid)
        cpu=$(ps -o pcpu= -p "${pid:-0}" 2>/dev/null | tr -d ' ')
        [ -z "$cpu" ] && cpu=0
        if ! awk -v c="$cpu" 'BEGIN { exit !(c < 1.0) }'; then
            stalled=0
            continue
        fi
        stalled=$((stalled + 15))
        if [ "$stalled" -ge "$STALL" ]; then
            echo ""
            echo "=== WATCHDOG: no output for ${stalled}s AND runner at ${cpu}% CPU -- sampling ==="
            if [ -n "$pid" ]; then
                sample "$pid" 2 -f "/tmp/idtest-stall-$pid.txt" >/dev/null 2>&1
                echo "--- blocking dispatch queues (pid $pid) ---"
                # `sample` writes `DispatchQueue_N: com.foo.bar`, not `Dispatch queue: ...`.
                # The obvious pattern matches nothing and the watchdog then fires with no
                # diagnosis at all -- which happened twice before this was noticed.
                grep -oE "DispatchQueue_[0-9]+: [a-zA-Z0-9._-]+|Dispatch queue: [a-zA-Z0-9._-]+" \
                    "/tmp/idtest-stall-$pid.txt" \
                    | sed 's/DispatchQueue_[0-9]*: //; s/Dispatch queue: //' \
                    | sort | uniq -c | sort -rn | head -5
                echo "--- full sample: /tmp/idtest-stall-$pid.txt ---"
            else
                echo "(could not locate the runner process to sample)"
            fi
            kill "$BUILD_PID" 2>/dev/null
            break
        fi
    done
) &
WATCHDOG_PID=$!

wait "$BUILD_PID"; BUILD_STATUS=$?
kill "$WATCHDOG_PID" 2>/dev/null; wait "$WATCHDOG_PID" 2>/dev/null

# Print EVERY summary line, not the first or the last. This suite emits one `Executed N tests` per
# target, so `| head -1` reports an unrelated target's zero and `| tail -1` reports a different
# target's total -- both read as the whole suite's result.
# NOT a bare `error:` -- the simulator's own runtime logging emits it freely (a clean run produced
# 81 CHHapticPattern lines), which makes a green suite look broken. Match the compiler form
# (path:line:col: error:) and real test failures only.
grep -E "Test Case .*' failed|^[^ ]+:[0-9]+:[0-9]+: error:|Executed [0-9]+ test|Restarting after unexpected exit|WATCHDOG" "$LOG"

echo ""
echo "xcodebuild exit=$BUILD_STATUS   full log: $LOG"
exit "$BUILD_STATUS"
