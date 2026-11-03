load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_unit_test")
load("@build_bazel_rules_apple//apple/testing/default_runner:ios_test_runner.bzl", "ios_test_runner")

swift_library(
    name = "NavigationBarNode",
    module_name = "NavigationBarNode",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/AsyncDisplayKit",
        "//submodules/Display",
        "//submodules/ComponentFlow",
        "//submodules/TelegramUI/Components/GlassBackgroundComponent",
        "//submodules/TelegramUI/Components/EdgeEffect",
        "//submodules/TelegramUI/Components/SideColumnLayout",
        "//submodules/TelegramUI/Components/NavigationBarComponent",
    ],
    visibility = [
        "//visibility:public",
    ],
)

swift_library(
    name = "NavigationBarNodeTestsLib",
    testonly = True,
    srcs = glob([
        "Tests/**/*.swift",
    ]),
    deps = [
        ":NavigationBarNode",
        "//submodules/AsyncDisplayKit",
        "//submodules/Display",
        "//submodules/ComponentFlow",
        "//submodules/TelegramUI/Components/NavigationBarComponent",
    ],
)

# The runner MUST pin a real device/OS: the default runner picks an invalid
# device and the test process exits 15. Matches SideColumnLayoutTests.
ios_test_runner(
    name = "NavigationBarNodeTestRunner",
    device_type = "iPhone 17",
    os_version = "26.5",
)

ios_unit_test(
    name = "NavigationBarNodeTests",
    minimum_os_version = "15.0",
    runner = ":NavigationBarNodeTestRunner",
    deps = [
        ":NavigationBarNodeTestsLib",
    ],
    visibility = [
        "//visibility:public",
    ],
)
