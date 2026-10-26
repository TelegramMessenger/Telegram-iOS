load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ChatMessageRichDataBubbleContentNode",
    module_name = "ChatMessageRichDataBubbleContentNode",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/AsyncDisplayKit",
        "//submodules/LottieSettings:LottieSettings",
        "//submodules/Display",
        "//submodules/TelegramCore",
        "//submodules/TelegramPresentationData",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/AccountContext",
        "//submodules/WalletContext",
        "//submodules/InstantPageUI",
        "//submodules/TextFormat:TextFormat",
        "//submodules/TelegramUI/Components/Chat/ChatMessageBubbleContentNode",
        "//submodules/TelegramUI/Components/Chat/ChatMessageDateAndStatusNode",
        "//submodules/TelegramUI/Components/Chat/ChatMessageItemCommon",
        "//submodules/TelegramUI/Components/Chat/ShimmeringLinkNode",
        "//submodules/TelegramUI/Components/ChatControllerInteraction",
        "//submodules/TelegramUI/Components/TextLoadingEffect",
        "//submodules/TelegramUIPreferences",
        "//submodules/TextSelectionNode",
        "//submodules/TelegramUI/Components/StreamingTextReveal:StreamingTextReveal",
    ],
    visibility = [
        "//visibility:public",
    ],
)
