load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_unit_test")
load("@build_bazel_rules_apple//apple/testing/default_runner:ios_test_runner.bzl", "ios_test_runner")

swift_library(
    name = "MediaPreuploadRegistry",
    module_name = "MediaPreuploadRegistry",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit",
    ],
    visibility = [
        "//visibility:public",
    ],
)

swift_library(
    name = "MediaPreuploadRegistryTestsLib",
    testonly = True,
    srcs = glob([
        "Tests/**/*.swift",
    ]),
    deps = [
        ":MediaPreuploadRegistry",
        "//submodules/SSignalKit/SwiftSignalKit",
    ],
)

ios_test_runner(
    name = "MediaPreuploadRegistryTestRunner",
    device_type = "iPhone 17",
    os_version = "26.5",
)

ios_unit_test(
    name = "MediaPreuploadRegistryTests",
    minimum_os_version = "15.0",
    runner = ":MediaPreuploadRegistryTestRunner",
    deps = [
        ":MediaPreuploadRegistryTestsLib",
    ],
    visibility = [
        "//visibility:public",
    ],
)
