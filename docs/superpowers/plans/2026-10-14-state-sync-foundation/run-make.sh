#!/bin/bash
# Usage: bash docs/superpowers/plans/2026-10-14-state-sync-foundation/run-make.sh test
#        bash docs/superpowers/plans/2026-10-14-state-sync-foundation/run-make.sh build
#
# `test` runs //submodules/TelegramCore:TelegramCoreTests; `build` runs the full app build with
# --continueOnError (debug_sim_arm64). Both use the Make.py invocation from CLAUDE.md. The codesigning
# password comes from ~/.zshrc, which the agent shell does not source. The full log goes to
# build-input/state-sync-<command>.log (gitignored); a summary is printed. Exit status is Make.py's.
set -u
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
cd "$ROOT" || exit 1
COMMAND="${1:-test}"
LOG="$ROOT/build-input/state-sync-$COMMAND.log"
mkdir -p "$ROOT/build-input"

TELEGRAM_CODESIGNING_GIT_PASSWORD="$(grep '^export TELEGRAM_CODESIGNING_GIT_PASSWORD=' ~/.zshrc | head -1 | sed -e 's/^export TELEGRAM_CODESIGNING_GIT_PASSWORD=//' -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")"
export TELEGRAM_CODESIGNING_GIT_PASSWORD

COMMON=(--configurationPath build-system/appstore-configuration.json
        --gitCodesigningRepository git@gitlab.com:peter-iakovlev/fastlanematch.git
        --gitCodesigningType development --gitCodesigningUseCurrent)

case "$COMMAND" in
test)
    python3 build-system/Make/Make.py --overrideXcodeVersion --cacheDir ~/telegram-bazel-cache \
        test "${COMMON[@]}" --target //submodules/TelegramCore:TelegramCoreTests > "$LOG" 2>&1
    STATUS=$?
    echo "make.py test exit status: $STATUS (log: $LOG)"
    TESTLOG="$ROOT/bazel-testlogs/submodules/TelegramCore/TelegramCoreTests/test.log"
    if [ -f "$TESTLOG" ]; then
        grep -E "Executed [0-9]+ tests" "$TESTLOG" | tail -1
        grep -E "error: -\[|failed \(" "$TESTLOG" | head -40
    fi
    grep -E "^ERROR|error: " "$LOG" | head -40
    exit $STATUS
    ;;
build)
    python3 build-system/Make/Make.py --overrideXcodeVersion --cacheDir ~/telegram-bazel-cache \
        build --continueOnError "${COMMON[@]}" --buildNumber=1 --configuration=debug_sim_arm64 > "$LOG" 2>&1
    STATUS=$?
    echo "make.py build exit status: $STATUS (log: $LOG)"
    grep -E "^ERROR|error: " "$LOG" | head -60
    tail -3 "$LOG"
    exit $STATUS
    ;;
*)
    echo "unknown command: $COMMAND (use test or build)"
    exit 2
    ;;
esac
