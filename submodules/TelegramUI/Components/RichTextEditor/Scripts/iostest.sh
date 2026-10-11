#!/bin/bash
# Runs the package's iOS-simulator tests. $1 = optional -only-testing filter
# (e.g. RichTextEditorUIKitTests/MapperTests). Set SCHEME/DEVICE env to override.
set -o pipefail
SCHEME="${SCHEME:-RichTextEditor-Package}"
DEVICE="${DEVICE:-03A7DA9C-1832-49B8-9858-2F54F2FB5A04}"  # iPhone 18 Pro K1 BY UDID — a bare `name=` collides across the K-sims and picks an
# ambiguous destination. Re-created by the Xcode 27 update (2026-09-15), which removed every simulator.
FILTER=""
[ -n "$1" ] && FILTER="-only-testing:$1"
# `-collect-test-diagnostics never`: on a FAILING run xcodebuild otherwise launches
# `simctl diagnose … --timeout=600`, which blocks the run for up to 10 MINUTES after the tests have
# already finished — with no output, so it reads as a hung compile. We never open the .xcresult's
# diagnostic bundle; the failure lines below are the whole signal.
# `grep --line-buffered`: without it the pipeline buffers and per-test progress only appears at the end.
# `TEST_RUNNER_RTE_FORCE_TK1` MUST be a genuine shell/process environment variable on xcodebuild
# itself — xcodebuild forwards TEST_RUNNER_-prefixed vars from ITS OWN environment to the test
# runner process, stripping the prefix. Passing `TEST_RUNNER_RTE_FORCE_TK1=1` as a trailing
# xcodebuild command-line argument (which looks like a build-setting override) does NOT reach the
# test process for this SwiftPM scheme — verified empirically (a diagnostic probe read the process
# environment under both forms; only the `export`ed form showed up). Do not revert to a trailing arg.
[ "${TK1:-0}" = "1" ] && export TEST_RUNNER_RTE_FORCE_TK1=1
# `Fatal error|Restarting after unexpected exit|[Cc]rash`: a Swift runtime trap (e.g. "Fatal error:
# Attempted to read an unowned reference but the object was already destroyed") kills the xctest
# process mid-run; xcodebuild silently relaunches it ("Restarting after unexpected exit, crash, or
# test timeout; summary will include totals from previous launches.") and resumes with the REMAINING
# tests. `set -o pipefail` keeps the exit code honest, but none of those three lines match the
# original filter, so the visible output could show a plausible "Executed N tests, 0 failures" from
# the post-restart partial run with the crash itself invisible above it — read as a clean pass. Found
# the hard way (Task 12 fix round 1): the crash was only visible by re-running xcodebuild raw, without
# this filter. Do not trim these alternatives as noise.
# `EXTRA` is INHERITED from the caller, never reset: matrix.sh (Task D1) and any A/B run append
# their own xcodebuild ARGUMENTS through it. It is deliberately NOT where the TK1 mapping lives --
# TEST_RUNNER_RTE_FORCE_TK1 must be an exported environment variable (see the comment above line
# 20); routing it through EXTRA would make it a trailing command-line argument, the form proven
# empirically NOT to reach the test process. Args here, environment there.
EXTRA="${EXTRA:-}"
xcodebuild test -scheme "$SCHEME" -destination "platform=iOS Simulator,id=$DEVICE" \
  -parallel-testing-enabled NO -collect-test-diagnostics never $FILTER $EXTRA 2>&1 \
  | grep --line-buffered -E "Test Case .*(passed|failed)|error:|BUILD (SUCCEEDED|FAILED)|Executed [0-9]+ test|Fatal error|Restarting after unexpected exit|[Cc]rash"
