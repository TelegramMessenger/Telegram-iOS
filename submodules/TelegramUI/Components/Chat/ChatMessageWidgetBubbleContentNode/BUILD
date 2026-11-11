load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_unit_test")
load("@build_bazel_rules_apple//apple/testing/default_runner:ios_test_runner.bzl", "ios_test_runner")

swift_library(
    name = "ChatMessageWidgetBubbleContentNode",
    module_name = "ChatMessageWidgetBubbleContentNode",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Display",
        "//submodules/UndoUI",
        "//submodules/AsyncDisplayKit",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/TelegramCore",
        "//submodules/TelegramPresentationData",
        "//submodules/TelegramUIPreferences",
        "//submodules/AccountContext",
        "//submodules/PresentationDataUtils",
        "//submodules/WalletContext",
        "//submodules/TelegramUI/Components/Chat/ChatMessageBubbleContentNode",
        "//submodules/TelegramUI/Components/Chat/ChatMessageDateAndStatusNode",
        "//submodules/TelegramUI/Components/Chat/ChatMessageItemCommon",
        "//submodules/TelegramUI/Components/ChatControllerInteraction",
        "//submodules/TelegramUI/Components/MessageWidget/MessageWidget",
        "//submodules/TelegramUI/Components/MessageWidget/MessageWidgetStorage",
        "//submodules/TelegramUI/Components/UnsupportedContentPill",
        "//submodules/TextSelectionNode",
        "//submodules/WallpaperBackgroundNode",
    ],
    visibility = [
        "//visibility:public",
    ],
)

swift_library(
    name = "ChatMessageWidgetBubbleContentNodeTestsLib",
    testonly = True,
    srcs = glob([
        "Tests/**/*.swift",
    ]),
    deps = [
        ":ChatMessageWidgetBubbleContentNode",
        "//submodules/AccountContext",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/WalletContext",
        "//submodules/TelegramCore",
        "//submodules/TelegramPresentationData",
        "//submodules/TelegramUIPreferences",
        "//submodules/TelegramUI/Components/Chat/ChatMessageItemCommon",
        "//submodules/TelegramUI/Components/MessageWidget/MessageWidget",
    ],
)

ios_test_runner(
    name = "ChatMessageWidgetBubbleContentNodeTestRunner",
    device_type = "iPhone 17",
    os_version = "26.5",
)

ios_unit_test(
    name = "ChatMessageWidgetBubbleContentNodeTests",
    minimum_os_version = "15.0",
    runner = ":ChatMessageWidgetBubbleContentNodeTestRunner",
    deps = [
        ":ChatMessageWidgetBubbleContentNodeTestsLib",
    ],
    visibility = [
        "//visibility:public",
    ],
)
