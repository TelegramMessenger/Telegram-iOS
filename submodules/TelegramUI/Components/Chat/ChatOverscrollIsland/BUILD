load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_unit_test")
load("@build_bazel_rules_apple//apple/testing/default_runner:ios_test_runner.bzl", "ios_test_runner")

# The island's geometry, without UIKit or AccountContext, so a test target can link it.
swift_library(
    name = "ChatOverscrollIslandLayout",
    module_name = "ChatOverscrollIslandLayout",
    srcs = glob([
        "Layout/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    visibility = [
        "//visibility:public",
    ],
)

swift_library(
    name = "ChatOverscrollIsland",
    module_name = "ChatOverscrollIsland",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        ":ChatOverscrollIslandLayout",
        "//submodules/Display",
        "//submodules/ComponentFlow",
        "//submodules/TelegramCore",
        "//submodules/AccountContext",
        "//submodules/AvatarNode",
        "//submodules/TelegramPresentationData",
        "//submodules/TelegramUI/Components/GlassBackgroundComponent",
    ],
    visibility = [
        "//visibility:public",
    ],
)

swift_library(
    name = "ChatOverscrollIslandLayoutTestsLib",
    testonly = True,
    srcs = glob([
        "Tests/**/*.swift",
    ]),
    deps = [
        ":ChatOverscrollIslandLayout",
    ],
)

# The runner MUST pin a real device/OS: the default runner picks an invalid device and the test process exits 15.
ios_test_runner(
    name = "ChatOverscrollIslandLayoutTestRunner",
    device_type = "iPhone 17",
    os_version = "26.5",
)

ios_unit_test(
    name = "ChatOverscrollIslandLayoutTests",
    minimum_os_version = "15.0",
    runner = ":ChatOverscrollIslandLayoutTestRunner",
    deps = [
        ":ChatOverscrollIslandLayoutTestsLib",
    ],
)
