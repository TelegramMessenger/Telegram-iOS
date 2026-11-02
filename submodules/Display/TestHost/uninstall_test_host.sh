#!/bin/bash
# pre_action of DisplayAccessibilityTestRunner. The runner reuses the "BAZEL_TEST_iPhone 17_26.5" simulator
# (REUSE_GLOBAL_SIMULATOR), and installd does NOT replace an installed app whose build number is unchanged, so without
# this a run silently tests the PREVIOUS host build — and the host carries Display and AsyncDisplayKit, the code under
# test. Same fix as Tests/ComposerHarness/Tools/uninstall_harness_from_test_sims.sh, but it also boots a shut-down
# simulator, since `simctl uninstall` needs a booted one.
set -u
for udid in $(xcrun simctl list devices | grep -E "BAZEL_TEST_iPhone 17_26\.5 \(" | grep -oE "[0-9A-F-]{36}"); do
  xcrun simctl bootstatus "$udid" -b >/dev/null 2>&1 || true
  xcrun simctl uninstall "$udid" org.telegram.DisplayAccessibilityTestHost >/dev/null 2>&1 || true
done
exit 0
