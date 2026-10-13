load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_unit_test")
load("@build_bazel_rules_apple//apple/testing/default_runner:ios_test_runner.bzl", "ios_test_runner")

swift_library(
    name = "LottieBinding",
    module_name = "LottieBinding",
    srcs = glob(["Sources/**/*.swift"]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/LottieSettings:LottieSettings",
        "//submodules/rlottie:RLottieBinding",
        "//submodules/tlottie:TLottieBinding",
    ],
    visibility = [
        "//visibility:public",
    ],
)

swift_library(
    name = "LottieBindingTestsLib",
    testonly = True,
    srcs = glob(["Tests/**/*.swift"]),
    deps = [
        ":LottieBinding",
        "//submodules/LottieSettings:LottieSettings",
        "//submodules/rlottie:RLottieBinding",
        "//submodules/tlottie:TLottieBinding",
    ],
)

# The runner must be pinned to a real device and OS. The default runner picks an
# invalid device and the test process exits 15.
ios_test_runner(
    name = "LottieBindingTestRunner",
    device_type = "iPhone 17",
    os_version = "26.5",
)

ios_unit_test(
    name = "LottieBindingTests",
    minimum_os_version = "15.0",
    runner = ":LottieBindingTestRunner",
    deps = [":LottieBindingTestsLib"],
    visibility = [
        "//visibility:public",
    ],
)
