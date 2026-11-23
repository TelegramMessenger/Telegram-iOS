load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_unit_test")
load("@build_bazel_rules_apple//apple/testing/default_runner:ios_test_runner.bzl", "ios_test_runner")

swift_library(
    name = "SupportUserInfoScreen",
    module_name = "SupportUserInfoScreen",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/Display",
        "//submodules/TelegramCore",
        "//submodules/TelegramPresentationData",
        "//submodules/AccountContext",
        "//submodules/ComponentFlow",
        "//submodules/Components/ViewControllerComponent",
        "//submodules/TelegramUI/Components/TextFieldComponent",
        "//submodules/TextFormat",
        "//submodules/UndoUI",
        "//submodules/PresentationDataUtils",
        "//submodules/ProgressNavigationButtonNode",
    ],
    visibility = [
        "//visibility:public",
    ],
)

swift_library(
    name = "SupportUserInfoScreenTestsLib",
    testonly = True,
    srcs = glob([
        "Tests/**/*.swift",
    ]),
    deps = [
        ":SupportUserInfoScreen",
        "//submodules/TelegramCore",
        "//submodules/TextFormat",
        "//submodules/Display",
        "//submodules/AsyncDisplayKit",
        "//submodules/UIKitRuntimeUtils:UIKitRuntimeUtils",
    ],
)

ios_test_runner(
    name = "SupportUserInfoScreenTestRunner",
    device_type = "iPhone 17",
    os_version = "26.5",
)

ios_unit_test(
    name = "SupportUserInfoScreenTests",
    minimum_os_version = "15.0",
    runner = ":SupportUserInfoScreenTestRunner",
    deps = [
        ":SupportUserInfoScreenTestsLib",
    ],
    visibility = [
        "//visibility:public",
    ],
)
