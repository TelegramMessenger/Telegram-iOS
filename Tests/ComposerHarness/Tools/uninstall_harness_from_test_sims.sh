#!/bin/bash
# pre_action of the harness test runners. The runners reuse one "BAZEL_TEST_<device>_<os>" simulator
# (REUSE_GLOBAL_SIMULATOR), and installd will NOT replace an installed app whose build number is
# unchanged — the harness is always CFBundleVersion 1 — so without this a run can silently test the
# PREVIOUS build (seen 2026-09-23). Uninstalling first makes the runner's install a fresh one.
set -u
for udid in $(xcrun simctl list devices | grep -E "BAZEL_TEST_.*\(Booted\)" | grep -oE "[0-9A-F-]{36}"); do
  xcrun simctl uninstall "$udid" org.telegram.ComposerHarness >/dev/null 2>&1 || true
done
exit 0
