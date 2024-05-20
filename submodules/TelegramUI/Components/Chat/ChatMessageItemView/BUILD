load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ChatMessageItemView",
    module_name = "ChatMessageItemView",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/AsyncDisplayKit",
        "//submodules/Display",
        "//submodules/Postbox",
        "//submodules/TelegramCore",
        "//submodules/AccountContext",
        "//submodules/LocalizedPeerData",
        "//submodules/ContextUI",
        "//submodules/ChatListUI",
        "//submodules/TelegramPresentationData",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/TelegramUI/Components/ChatControllerInteraction",
        "//submodules/TelegramUI/Components/Chat/ChatMessageItemCommon",
        "//submodules/TextFormat",
        "//submodules/TelegramUI/Components/Chat/ChatMessageItem",
        "//submodules/TelegramUI/Components/Chat/ChatMessageTransitionNode",
        "//submodules/TelegramAnimatedStickerNode",
    ],
    visibility = [
        "//visibility:public",
    ],
)
