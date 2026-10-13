load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_unit_test")
load("@build_bazel_rules_apple//apple/testing/default_runner:ios_test_runner.bzl", "ios_test_runner")

swift_library(
    name = "DatePickerNode",
    module_name = "DatePickerNode",
    srcs = glob([
		"Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/AsyncDisplayKit",
        "//submodules/Display",
        "//submodules/TelegramPresentationData",
        "//submodules/TelegramStringFormatting",
        "//submodules/SegmentedControlNode",
        "//submodules/DirectionalPanGesture",
        "//submodules/TextFormat",
    ],
    visibility = [
        "//visibility:public",
    ],
)

swift_library(
    name = "DatePickerNodeTestsLib",
    testonly = True,
    srcs = glob([
        "Tests/**/*.swift",
    ]),
    deps = [
        ":DatePickerNode",
    ],
)

# The runner MUST pin a real device/OS: the default runner picks an invalid
# device and the test process exits 15.
ios_test_runner(
    name = "DatePickerNodeTestRunner",
    device_type = "iPhone 17",
    os_version = "26.5",
)

ios_unit_test(
    name = "DatePickerNodeTests",
    minimum_os_version = "15.0",
    runner = ":DatePickerNodeTestRunner",
    deps = [
        ":DatePickerNodeTestsLib",
    ],
    visibility = [
        "//visibility:public",
    ],
)
