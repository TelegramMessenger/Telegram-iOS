load("@rules_cc//cc:cc_library.bzl", "cc_library")
load("@rules_cc//cc:cc_test.bzl", "cc_test")
load("@rules_cc//cc:objc_library.bzl", "objc_library")

quickjs_copts = [
    "-O2",
    "-w",
    "-D_GNU_SOURCE",
    "-DQUICKJS_NG_BUILD",
    # The interrupt poll every 100 operations, not upstream's 10,000: a loop of costly builtins (a 4 MB
    # `repeat`) otherwise runs ~40 s past a message widget's 500 ms deadline. VENDOR.md, local edit 1.
    "-DJS_INTERRUPT_COUNTER_INIT=100",
    "-Ithird-party/quickjs-ng/include",
    "-Ithird-party/quickjs-ng/quickjs",
]

cc_library(
    name = "quickjs",
    srcs = [
        "quickjs/quickjs.c",
        "quickjs/dtoa.c",
        "quickjs/libregexp.c",
        "quickjs/libunicode.c",
        "shim/qjs_shim.c",
    ] + glob(["quickjs/*.h"]),
    hdrs = [
        "include/quickjs.h",
        "include/qjs_shim.h",
    ],
    includes = ["include"],
    copts = quickjs_copts,
    visibility = ["//visibility:public"],
)

objc_library(
    name = "CQuickJS",
    module_name = "CQuickJS",
    enable_modules = True,
    hdrs = [
        "include/quickjs.h",
        "include/qjs_shim.h",
    ],
    includes = ["include"],
    deps = [":quickjs"],
    visibility = ["//visibility:public"],
)

cc_test(
    name = "QuickJSSmokeTests",
    srcs = ["tests/quickjs_smoke_test.c"],
    copts = quickjs_copts,
    deps = [":quickjs"],
)

cc_test(
    name = "QuickJSWorkTests",
    srcs = ["tests/quickjs_work_test.c"],
    copts = quickjs_copts,
    deps = [":quickjs"],
)

# Fork changes 3-12 (VENDOR.md): host auto-init properties, class prototypes on first use, string access, a host-class
# global object, host time and randomness, an uncatchable error through a Promise executor, a host hook at the memory
# limit, the host's stop, the loaded-module walks charged, no dumps without an explicit opt-in.
cc_test(
    name = "QuickJSHostTests",
    srcs = ["tests/quickjs_host_test.c"],
    copts = quickjs_copts,
    deps = [":quickjs"],
)

# Cost coverage and calibration of the work counter (VENDOR.md local edit 2). It measures wall time, so it is manual (not
# in `:all`) and meaningful only optimized, on a quiet machine:
# ./build-input/bazel-9.2.0-darwin-arm64 test -c opt //third-party/quickjs-ng:QuickJSWorkCostTests --test_output=all
cc_test(
    name = "QuickJSWorkCostTests",
    srcs = ["tests/quickjs_work_cost_test.c"],
    copts = quickjs_copts,
    deps = [":quickjs"],
    size = "large",
    tags = ["manual"],
)

# The native-path sweep (VENDOR.md local edit 2): every builtin with large inputs, each call's wall time per unit
# against the reference loop; a slow or never-ending call is a native path the counter does not charge. A report, slow
# and timing-dependent, so not in `:all`. Optimized, on a quiet machine:
# ./build-input/bazel-9.2.0-darwin-arm64 test -c opt //third-party/quickjs-ng:QuickJSNativeSweep --test_output=all
cc_test(
    name = "QuickJSNativeSweep",
    srcs = ["tests/quickjs_native_sweep_test.c"],
    copts = quickjs_copts,
    data = ["tests/native_sweep.js"],
    args = ["$(location tests/native_sweep.js)"],
    deps = [":quickjs"],
    size = "enormous",
    tags = ["manual"],
)

# The sources :quickjs compiles, for WidgetRuntime's no-I/O scan (NoIOScanTests).
filegroup(
    name = "ScanSources",
    testonly = True,
    srcs = [
        "quickjs/quickjs.c",
        "quickjs/dtoa.c",
        "quickjs/libregexp.c",
        "quickjs/libunicode.c",
        "shim/qjs_shim.c",
    ] + glob(["quickjs/*.h", "include/*.h"]),
    visibility = ["//submodules/TelegramUI/Components/MessageWidget/WidgetRuntime:__pkg__"],
)
