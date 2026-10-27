#!/bin/bash
# pre_action of the widget harness test runners. The runners reuse one "BAZEL_TEST_<device>_<os>" simulator
# (REUSE_GLOBAL_SIMULATOR), and installd will NOT replace an installed app whose build number is unchanged — the
# harness is always CFBundleVersion 1 — so without this a run can silently test the PREVIOUS build
# (Tests/ComposerHarness/CLAUDE.md). Uninstalling first makes the runner's install a fresh one. The UI tests' runner app
# (which carries the test bundle) is the same: left installed, a run executed an earlier build of the UI tests.
set -u
for udid in $(xcrun simctl list devices | grep -E "BAZEL_TEST_.*\(Booted\)" | grep -oE "[0-9A-F-]{36}"); do
  xcrun simctl uninstall "$udid" org.telegram.WidgetHarness >/dev/null 2>&1 || true
  xcrun simctl uninstall "$udid" com.apple.test.WidgetHarnessUITests-Runner >/dev/null 2>&1 || true
done
exit 0
