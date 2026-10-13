load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_unit_test")
load("@build_bazel_rules_apple//apple/testing/default_runner:ios_test_runner.bzl", "ios_test_runner")

swift_library(
    name = "ChatMessageBackground",
    module_name = "ChatMessageBackground",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
    	"//submodules/Display:Display",
    	"//submodules/TelegramPresentationData:TelegramPresentationData",
    	"//submodules/WallpaperBackgroundNode:WallpaperBackgroundNode",
    	"//submodules/AppBundle:AppBundle",
    ],
    visibility = [
        "//visibility:public",
    ],
)

swift_library(
    name = "ChatMessageBackgroundTestsLib",
    testonly = True,
    srcs = glob([
        "Tests/**/*.swift",
    ]),
    deps = [
        ":ChatMessageBackground",
        "//submodules/Display:Display",
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
    ],
)

# The runner MUST pin a real device/OS: the default runner picks an invalid
# device and the test process exits 15. Matches //submodules/InstantPageUI:InstantPageUITests.
ios_test_runner(
    name = "ChatMessageBackgroundTestRunner",
    device_type = "iPhone 17",
    os_version = "26.5",
)

ios_unit_test(
    name = "ChatMessageBackgroundTests",
    minimum_os_version = "15.0",
    runner = ":ChatMessageBackgroundTestRunner",
    deps = [
        ":ChatMessageBackgroundTestsLib",
    ],
    visibility = [
        "//visibility:public",
    ],
)
