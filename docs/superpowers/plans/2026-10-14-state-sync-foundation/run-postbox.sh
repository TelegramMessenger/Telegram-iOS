#!/bin/bash
# Usage: bash docs/superpowers/plans/2026-10-14-state-sync-foundation/run-postbox.sh
#
# Runs //submodules/Postbox:PostboxTests with the Make.py invocation from CLAUDE.md (the sibling of run-make.sh, which
# runs TelegramCoreTests). The codesigning password comes from ~/.zshrc, which the agent shell does not source. The full
# log goes to build-input/postbox-test.log (gitignored); a summary is printed. Exit status is Make.py's.
set -u
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
cd "$ROOT" || exit 1
LOG="$ROOT/build-input/postbox-test.log"
mkdir -p "$ROOT/build-input"

TELEGRAM_CODESIGNING_GIT_PASSWORD="$(grep '^export TELEGRAM_CODESIGNING_GIT_PASSWORD=' ~/.zshrc | head -1 | sed -e 's/^export TELEGRAM_CODESIGNING_GIT_PASSWORD=//' -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")"
export TELEGRAM_CODESIGNING_GIT_PASSWORD

python3 build-system/Make/Make.py --overrideXcodeVersion --cacheDir ~/telegram-bazel-cache \
    test --configurationPath build-system/appstore-configuration.json \
    --gitCodesigningRepository git@gitlab.com:peter-iakovlev/fastlanematch.git \
    --gitCodesigningType development --gitCodesigningUseCurrent \
    --target //submodules/Postbox:PostboxTests > "$LOG" 2>&1
STATUS=$?
echo "make.py test exit status: $STATUS (log: $LOG)"
TESTLOG="$(ls -t "$ROOT"/bazel-out/*/testlogs/submodules/Postbox/PostboxTests/test.log 2>/dev/null | head -1)"
if [ -n "$TESTLOG" ]; then
    grep -E "Executed [0-9]+ tests" "$TESTLOG" | tail -1
    grep -E "error: -\[|failed \(" "$TESTLOG" | head -40
fi
grep -E "^ERROR|error: " "$LOG" | head -40
exit $STATUS
