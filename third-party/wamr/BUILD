# WAMR 2.4.5 (Apache-2.0), interpreter-only configuration.
# iOS-safe: no JIT/AOT, no signal handlers (HW bound check disabled).
# Sources are vendored verbatim; configuration happens here via defines only.

# SAFETY: the two sigaction sites in the vendored sources (posix_thread.c HW
# bound-check traps, posix_blocking_op.c SIGUSR1) are dead ONLY because
# WASM_DISABLE_HW_BOUND_CHECK=1 and WASM_ENABLE_THREAD_MGR=0 below. Re-audit
# signal-handler reachability before flipping either define (iOS forbids
# installing signal handlers in the app process).

load("@rules_cc//cc:cc_library.bzl", "cc_library")

wamr_copts = [
    "-Ithird-party/wamr/core",
    "-Ithird-party/wamr/core/iwasm/include",
    "-Ithird-party/wamr/core/iwasm/common",
    "-Ithird-party/wamr/core/iwasm/interpreter",
    "-Ithird-party/wamr/core/iwasm/libraries/libc-wasi",
    "-Ithird-party/wamr/core/iwasm/libraries/libc-wasi/sandboxed-system-primitives/include",
    "-Ithird-party/wamr/core/iwasm/libraries/libc-wasi/sandboxed-system-primitives/src",
    "-Ithird-party/wamr/core/shared/platform/include",
    "-Ithird-party/wamr/core/shared/platform/common/libc-util",
    "-Ithird-party/wamr/core/shared/mem-alloc",
    "-Ithird-party/wamr/core/shared/utils",
    "-DWASM_ENABLE_INTERP=1",
    "-DWASM_ENABLE_FAST_INTERP=1",
    "-DWASM_ENABLE_LIBC_WASI=1",
    "-DWASM_ENABLE_LIBC_BUILTIN=0",
    "-DWASM_ENABLE_MINI_LOADER=0",
    "-DWASM_ENABLE_AOT=0",
    "-DWASM_ENABLE_JIT=0",
    "-DWASM_ENABLE_FAST_JIT=0",
    "-DWASM_ENABLE_SIMD=0",
    "-DWASM_ENABLE_REF_TYPES=1",
    "-DWASM_ENABLE_BULK_MEMORY=1",
    "-DWASM_ENABLE_SHARED_MEMORY=0",
    "-DWASM_ENABLE_THREAD_MGR=0",
    "-DWASM_ENABLE_MULTI_MODULE=0",
    "-DWASM_ENABLE_MODULE_INST_CONTEXT=1",
    "-DWASM_DISABLE_HW_BOUND_CHECK=1",
    "-DWASM_DISABLE_STACK_HW_BOUND_CHECK=1",
    "-DBH_MALLOC=wasm_runtime_malloc",
    "-DBH_FREE=wasm_runtime_free",
    "-DBUILD_TARGET_AARCH64=1",
    "-DBUILD_TARGET=\\\"AARCH64\\\"",
    "-w",
] + select({
    "@platforms//os:linux": ["-DBH_PLATFORM_LINUX", "-Ithird-party/wamr/core/shared/platform/linux"],
    "//conditions:default": ["-DBH_PLATFORM_DARWIN", "-Ithird-party/wamr/core/shared/platform/darwin"],
})

cc_library(
    name = "wamr",
    srcs = glob([
        "core/iwasm/common/*.c",
        "core/iwasm/libraries/libc-wasi/*.c",
        "core/iwasm/libraries/libc-wasi/sandboxed-system-primitives/src/*.c",
        "core/shared/mem-alloc/*.c",
        "core/shared/mem-alloc/ems/*.c",
        "core/shared/utils/*.c",
        "core/shared/platform/common/posix/*.c",
        "core/shared/platform/common/libc-util/*.c",
        "core/shared/platform/common/memory/*.c",
    ]) + [
        "core/iwasm/interpreter/wasm_interp_fast.c",
        "core/iwasm/interpreter/wasm_loader.c",
        "core/iwasm/interpreter/wasm_runtime.c",
        "core/iwasm/common/arch/invokeNative_aarch64.s",
    ] + select({
        "@platforms//os:linux": ["core/shared/platform/linux/platform_init.c"],
        "//conditions:default": ["core/shared/platform/darwin/platform_init.c"],
    }),
    hdrs = glob(["core/**/*.h", "LICENSE"]),
    copts = wamr_copts,
    includes = ["core/iwasm/include"],
    visibility = ["//visibility:public"],
)
