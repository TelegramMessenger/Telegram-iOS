load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_unit_test")
load("@build_bazel_rules_apple//apple/testing/default_runner:ios_test_runner.bzl", "ios_test_runner")

swift_library(
    name = "ChatMessageItemCommon",
    module_name = "ChatMessageItemCommon",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Display",
        "//submodules/TelegramCore",
        "//submodules/Emoji",
    ],
    visibility = [
        "//visibility:public",
    ],
)

swift_library(
    name = "ChatMessageItemCommonTestsLib",
    testonly = True,
    srcs = glob([
        "Tests/**/*.swift",
    ]),
    deps = [
        ":ChatMessageItemCommon",
        "//submodules/Display",
        "//submodules/TelegramCore",
        "//submodules/Postbox",
    ],
)

ios_test_runner(
    name = "ChatMessageItemCommonTestRunner",
    device_type = "iPhone 17",
    os_version = "26.5",
)

ios_unit_test(
    name = "ChatMessageItemCommonTests",
    minimum_os_version = "15.0",
    runner = ":ChatMessageItemCommonTestRunner",
    deps = [
        ":ChatMessageItemCommonTestsLib",
    ],
    visibility = [
        "//visibility:public",
    ],
)
