# Patches to external repositories

`MODULE.bazel` applies the patches in this directory.

## `xctestrunner-collect-test-diagnostics.patch`

rules_apple's `ios_test_runner` drives xcodebuild through xctestrunner, which passes `-collect-test-diagnostics=never`.
xcodebuild reads that `=` spelling as a build setting and silently ignores it (`-collect-test-diagnostics=bogus` is
accepted; `-collect-test-diagnostics bogus` is rejected), so diagnostics stay `on-failure` and every failing run ends in
`simctl diagnose -l -b --timeout=600 …`, which can hold the run for up to 10 minutes after its last test (and the
timeout stops while the Mac sleeps). The patch passes the flag and its value as two arguments. An xctestrunner bump that
no longer matches the patch fails the build rather than quietly bringing the stall back.

**If a failing run still stalls after its `Test Suite … failed` line:** `pgrep -fl "simctl diagnose"`. A hit means the
patch is not in effect; killing that process is safe (it only collects logs) and the run returns at once with its real
result. Scripts that call xcodebuild themselves pass `-collect-test-diagnostics never`, as two arguments.
