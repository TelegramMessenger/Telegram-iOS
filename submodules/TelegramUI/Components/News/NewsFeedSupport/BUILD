load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_unit_test")
load("@build_bazel_rules_apple//apple/testing/default_runner:ios_test_runner.bzl", "ios_test_runner")

swift_library(
    name = "NewsFeedSupport",
    module_name = "NewsFeedSupport",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/TelegramCore:TelegramCore",
    ],
    visibility = [
        "//visibility:public",
    ],
)

swift_library(
    name = "NewsFeedSupportTestsLib",
    testonly = True,
    srcs = glob([
        "Tests/**/*.swift",
    ]),
    deps = [
        ":NewsFeedSupport",
        "//submodules/TelegramCore:TelegramCore",
    ],
)

ios_test_runner(
    name = "NewsFeedSupportTestRunner",
    device_type = "iPhone 17",
    os_version = "26.5",
)

ios_unit_test(
    name = "NewsFeedSupportTests",
    minimum_os_version = "15.0",
    runner = ":NewsFeedSupportTestRunner",
    deps = [
        ":NewsFeedSupportTestsLib",
    ],
    visibility = [
        "//visibility:public",
    ],
)
