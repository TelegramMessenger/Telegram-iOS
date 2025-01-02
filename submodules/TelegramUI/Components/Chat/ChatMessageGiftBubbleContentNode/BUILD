load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ChatMessageGiftBubbleContentNode",
    module_name = "ChatMessageGiftBubbleContentNode",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/AsyncDisplayKit",
        "//submodules/Display",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/TelegramCore",
        "//submodules/AccountContext",
        "//submodules/TelegramPresentationData",
        "//submodules/TelegramUIPreferences",
        "//submodules/TextFormat",
        "//submodules/LocalizedPeerData",
        "//submodules/UrlEscaping",
        "//submodules/TelegramStringFormatting",
        "//submodules/WallpaperBackgroundNode",
        "//submodules/ReactionSelectionNode",
        "//submodules/AnimatedStickerNode",
        "//submodules/TelegramAnimatedStickerNode",
        "//submodules/TelegramUI/Components/ChatControllerInteraction",
        "//submodules/ShimmerEffect",
        "//submodules/Markdown",
        "//submodules/TelegramUI/Components/Chat/ChatMessageBubbleContentNode",
        "//submodules/TelegramUI/Components/Chat/ChatMessageItemCommon",
        "//submodules/TelegramUI/Components/TextNodeWithEntities",
        "//submodules/InvisibleInkDustNode",
        "//submodules/TelegramUI/Components/PeerInfo/PeerInfoCoverComponent",
    ],
    visibility = [
        "//visibility:public",
    ],
)
