load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_unit_test")
load("@build_bazel_rules_apple//apple/testing/default_runner:ios_test_runner.bzl", "ios_test_runner")

swift_library(
    name = "ChatSendStarsScreen",
    module_name = "ChatSendStarsScreen",
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
        "//submodules/ChatPresentationInterfaceState",
        "//submodules/AccountContext",
        "//submodules/ComponentFlow",
        "//submodules/ContextUI",
        "//submodules/AppBundle",
        "//submodules/Components/ViewControllerComponent",
        "//submodules/Components/ComponentDisplayAdapters",
        "//submodules/TelegramCore",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/Components/MultilineTextComponent",
        "//submodules/TelegramUI/Components/ButtonComponent",
        "//submodules/TelegramUI/Components/PlainButtonComponent",
        "//submodules/Markdown",
        "//submodules/TelegramUI/Components/EmojiStatusComponent",
        "//submodules/TelegramUI/Components/SliderComponent",
        "//submodules/TelegramUI/Components/Utils/RoundedRectWithTailPath",
        "//submodules/TelegramUI/Components/CheckComponent",
        "//submodules/AvatarNode",
        "//submodules/Components/BundleIconComponent",
        "//submodules/CheckNode",
        "//submodules/TextFormat",
        "//submodules/TelegramUI/Components/Stars/StarsBalanceOverlayComponent",
        "//submodules/TelegramStringFormatting",
        "//submodules/TelegramUI/Components/ChatScheduleTimeController",
        "//submodules/TelegramUI/Components/Stories/LiveChat/StoryLiveChatMessageComponent",
    ],
    visibility = [
        "//visibility:public",
    ],
)

swift_library(
    name = "ChatSendStarsScreenTestsLib",
    testonly = True,
    srcs = glob([
        "Tests/**/*.swift",
    ]),
    deps = [
        ":ChatSendStarsScreen",
        "//submodules/TelegramCore",
    ],
)

ios_test_runner(
    name = "ChatSendStarsScreenTestRunner",
    device_type = "iPhone 17",
    os_version = "26.5",
)

ios_unit_test(
    name = "ChatSendStarsScreenTests",
    minimum_os_version = "15.0",
    runner = ":ChatSendStarsScreenTestRunner",
    deps = [
        ":ChatSendStarsScreenTestsLib",
    ],
    visibility = [
        "//visibility:public",
    ],
)
