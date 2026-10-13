load("@rules_cc//cc:objc_library.bzl", "objc_library")

load("@rules_rust//rust:defs.bzl", "rust_static_library", "rust_test")

# Pinned, not inherited. rules_rust follows Bazel's compilation mode, so under
# --configuration=debug_sim_arm64 this rasterizer would otherwise compile at
# -Copt-level=0. wallet-engine uses -Copt-level=z, which is right for a crypto
# library and wrong here.
#
# -Cpanic=abort: a Rust panic cannot unwind across `extern "C"` anyway (Rust
# aborts at the boundary), so this costs no recoverability and saves the
# landing-pad tables. Consequence to know: a tlottie bug is an app crash, where
# the C++ rlottie would more likely render garbage.
_TLOTTIE_FLAGS = [
    "-Copt-level=3",
    "-Ccodegen-units=1",
    "-Cpanic=abort",
]

_TLOTTIE_SRCS = glob(["tlottie/src/**/*.rs"])

_TLOTTIE_FEATURES = [
    "cpu",
    "std",
    "c-api",
]

rust_static_library(
    name = "tlottie_archive",
    crate_name = "tlottie",
    crate_root = "tlottie/src/lib.rs",
    srcs = _TLOTTIE_SRCS,
    crate_features = _TLOTTIE_FEATURES,
    edition = "2021",
    rustc_flags = _TLOTTIE_FLAGS,
    visibility = ["//visibility:public"],
)

# Tagged manual so it never joins an app build; run explicitly to verify a
# vendored revision.
rust_test(
    name = "tlottie_upstream_test",
    crate_name = "tlottie",
    crate_root = "tlottie/src/lib.rs",
    srcs = _TLOTTIE_SRCS,
    compile_data = glob(
        ["tlottie/src/**/testdata/**"],
        allow_empty = True,
    ),
    crate_features = _TLOTTIE_FEATURES,
    edition = "2021",
    tags = ["manual"],
)


load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_unit_test")
load("@build_bazel_rules_apple//apple/testing/default_runner:ios_test_runner.bzl", "ios_test_runner")

objc_library(
    name = "TLottieBinding",
    module_name = "TLottieBinding",
    enable_modules = True,
    srcs = [
        "TLottieAnimation.mm",
        "tlottie/include/tlottie.h",
    ],
    hdrs = glob(["PublicHeaders/**/*.h"]),
    includes = ["PublicHeaders"],
    copts = [
        "-I{}/tlottie/include".format(package_name()),
    ],
    deps = [
        ":tlottie_archive",
    ],
    visibility = ["//visibility:public"],
)

swift_library(
    name = "TLottieBindingTestsLib",
    testonly = True,
    srcs = glob(["Tests/**/*.swift"]),
    deps = [":TLottieBinding"],
)

# The runner must be pinned to a real device and OS. The default runner picks an
# invalid device and the test process exits 15.
ios_test_runner(
    name = "TLottieBindingTestRunner",
    device_type = "iPhone 17",
    os_version = "26.5",
)

ios_unit_test(
    name = "TLottieBindingTests",
    minimum_os_version = "15.0",
    runner = ":TLottieBindingTestRunner",
    deps = [":TLottieBindingTestsLib"],
    visibility = ["//visibility:public"],
)
