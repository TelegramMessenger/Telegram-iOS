#!/bin/bash
# ==============================================================================================
# Builds — and optionally installs and launches — the InputDec HOST APP (task PH4).
#
# This is the only surface on which a human can type into the ported InputDec engine. Telegram is
# closed to it (`IDBlockTextView.m`'s `+load` runs before `main()` and can `@throw` uncaught, which
# no runtime flag can gate), so every hands-on defect from here on has to come through this app.
#
#   ./Scripts/hostapp.sh            build, install and launch on the default simulator
#   ./Scripts/hostapp.sh build      build only (no simulator is touched)
#   ./Scripts/hostapp.sh test       run BOTH test bundles — InputDecHost and InputDecEngine
#
# `test` runs TWO schemes. `InputDecHost` is the hosted bundle (the pixel experiment + smoke tests);
# `InputDecEngine` is the ENGINE's own suite, which this script did not run until 2026-09-15 — so a
# change to `Sources/RichTextInputDecUpstream/` could go green here while breaking the engine's own
# contracts, which is exactly what happened to the block-selection work. Both run even when the first
# fails, so one invocation reports the whole picture; the exit code is non-zero if either failed.
#
# `test` REPORTS EXPECTED FAILURES in both bundles, and none of them is a broken test:
#   InputDecHost   — `IDHostedSpellingUnderlineParityTests` reproduces the user's still-open
#                    "corrected words are not underlined" defect, and `IDHostedIsolatedUnderlineArm`
#                    reproduces two arms of the same one. They went red the first time they were run
#                    — that is what they are for. Read those files' headers before touching them.
#   InputDecEngine — NONE. It was six until 2026-09-15, all of them the same thing: authorization
#                    fixtures asserting that upstream's own `.xcresult` RUN RECORDS are on disk. They
#                    are not, and 26 of the 48 cited exist nowhere at all, so the check was
#                    unsatisfiable rather than failing. The fixtures' CONTENTS are still asserted in
#                    full; see `IDIsUpstreamRunArtifactPath`.
#                    (Separate from both bundles: the SwiftPM suite's `LegacyDifferentialTests` and
#                    `IDUpstreamResponderModelTests` ARE environmental on iOS 27 — see the package
#                    CLAUDE.md's "The K-sims moved to iOS 27" section.)
#   DEVICE=<udid> ./Scripts/hostapp.sh    use a different simulator
#
# DEVICE defaults to iPhone 18 Pro **K1** and NOT K3. K3 is the simulator the project's Telegram
# install recipe targets and the one every InputDec matrix script pins; keeping this app off it means
# a host-app session can never disturb a logged-in Telegram. Change it only deliberately.
# ==============================================================================================
set -euo pipefail
cd "$(dirname "$0")/.."

DEVICE="${DEVICE:-03A7DA9C-1832-49B8-9858-2F54F2FB5A04}"   # iPhone 18 Pro K1
BUNDLE_ID="com.inputdechost.InputDecHost"
MODE="${1:-run}"

command -v xcodegen >/dev/null || {
  echo "xcodegen is not installed: brew install xcodegen" >&2; exit 1; }

# The .xcodeproj is generated, never committed (.gitignore). Regenerating every time is what keeps
# a stale project from silently building yesterday's file list — the same class of trap as the
# project CLAUDE.md's `Telegram_archive-root/` staleness note.
xcodegen generate --spec Host/project.yml --project Host >/dev/null

DEST="platform=iOS Simulator,id=$DEVICE"
DERIVED="Host/build"

case "$MODE" in
  test)
    # Run both schemes to completion. `set -e` would stop at the first failing bundle and hide the
    # other's result, which is the opposite of what a test run is for, so each status is captured.
    status=0
    for scheme in InputDecHost InputDecEngine; do
      echo "=== $scheme ==="
      xcodebuild test -project Host/InputDecHost.xcodeproj -scheme "$scheme" \
        -destination "$DEST" -derivedDataPath "$DERIVED" \
        -parallel-testing-enabled NO -collect-test-diagnostics never || status=1
    done
    exit "$status"
    ;;
  build|run) ;;
  *) echo "usage: $0 [build|run|test]" >&2; exit 2 ;;
esac

xcodebuild build -project Host/InputDecHost.xcodeproj -scheme InputDecHost \
  -destination "$DEST" -derivedDataPath "$DERIVED" \
  | grep -E "error:|warning: .*(deprecat|unused)|\*\* BUILD" || true

APP="$DERIVED/Build/Products/Debug-iphonesimulator/InputDecHost.app"
[ -x "$APP/InputDecHost" ] || { echo "no app at $APP — the build did not produce one" >&2; exit 1; }
echo "app: $APP"

[ "$MODE" = "build" ] && exit 0

xcrun simctl boot "$DEVICE" 2>/dev/null || true
xcrun simctl bootstatus "$DEVICE" -b >/dev/null
# `uninstall` first: installd keeps a hard-link cache and will NOT replace an already-installed app
# whose build number has not changed, so a rebuilt binary silently does not take effect. This is the
# same trap the project CLAUDE.md documents for Telegram; here the app has no state worth keeping,
# so the blunt fix is the right one.
xcrun simctl uninstall "$DEVICE" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl install "$DEVICE" "$APP"
xcrun simctl launch "$DEVICE" "$BUNDLE_ID"
open -a Simulator --args -CurrentDeviceUDID "$DEVICE" 2>/dev/null || true
echo "launched $BUNDLE_ID on $DEVICE"
