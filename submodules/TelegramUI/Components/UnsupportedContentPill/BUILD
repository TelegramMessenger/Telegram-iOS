load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_unit_test")
load("@build_bazel_rules_apple//apple/testing/default_runner:ios_test_runner.bzl", "ios_test_runner")

swift_library(
    name = "UnsupportedContentPill",
    module_name = "UnsupportedContentPill",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Display",
        "//submodules/AsyncDisplayKit",
        "//submodules/TelegramPresentationData",
        "//submodules/WallpaperBackgroundNode",
        "//submodules/AppBundle",
    ],
    visibility = [
        "//visibility:public",
    ],
)

swift_library(
    name = "UnsupportedContentPillTestsLib",
    testonly = True,
    srcs = glob([
        "Tests/**/*.swift",
    ]),
    deps = [
        ":UnsupportedContentPill",
        "//submodules/Display",
    ],
)

# The runner MUST pin a real device/OS: the default runner picks an invalid
# device and the test process exits 15. Matches //submodules/InstantPageUI:InstantPageUITests.
ios_test_runner(
    name = "UnsupportedContentPillTestRunner",
    device_type = "iPhone 17",
    os_version = "26.5",
)

ios_unit_test(
    name = "UnsupportedContentPillTests",
    minimum_os_version = "15.0",
    runner = ":UnsupportedContentPillTestRunner",
    deps = [
        ":UnsupportedContentPillTestsLib",
    ],
    visibility = [
        "//visibility:public",
    ],
)
