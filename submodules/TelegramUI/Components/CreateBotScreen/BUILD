load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_unit_test")
load("@build_bazel_rules_apple//apple/testing/default_runner:ios_test_runner.bzl", "ios_test_runner")

swift_library(
    name = "CreateBotScreen",
    module_name = "CreateBotScreen",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Display",
        "//submodules/TelegramPresentationData",
        "//submodules/ComponentFlow",
        "//submodules/Components/ViewControllerComponent",
        "//submodules/Components/ComponentDisplayAdapters",
        "//submodules/AccountContext",
        "//submodules/Components/MultilineTextComponent",
        "//submodules/Components/BalancedTextComponent",
        "//submodules/TelegramUI/Components/ButtonComponent",
        "//submodules/Components/BundleIconComponent",
        "//submodules/TelegramCore",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/PresentationDataUtils",
        "//submodules/Components/ResizableSheetComponent",
        "//submodules/TelegramUI/Components/GlassBarButtonComponent",
        "//submodules/TelegramUI/Components/PlainButtonComponent",
        "//submodules/TelegramUI/Components/ListSectionComponent",
        "//submodules/TelegramUI/Components/AvatarComponent",
        "//submodules/TelegramUI/Components/ListMultilineTextFieldItemComponent",
        "//submodules/Markdown",
    ],
    visibility = [
        "//visibility:public",
    ],
)

swift_library(
    name = "BotUsernameTestsLib",
    testonly = True,
    srcs = ["Sources/BotUsernameConfiguration.swift"] + glob(["Tests/**/*.swift"]),
)

ios_test_runner(
    name = "BotUsernameTestRunner",
    device_type = "iPhone 17",
    os_version = "26.5",
)

ios_unit_test(
    name = "BotUsernameTests",
    minimum_os_version = "15.0",
    runner = ":BotUsernameTestRunner",
    deps = [":BotUsernameTestsLib"],
    visibility = ["//visibility:public"],
)
