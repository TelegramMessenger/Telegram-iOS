load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ChatMessageActionBubbleContentNode",
    module_name = "ChatMessageActionBubbleContentNode",
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
        "//submodules/Postbox",
        "//submodules/TelegramCore",
        "//submodules/AccountContext",
        "//submodules/TelegramPresentationData",
        "//submodules/TelegramUIPreferences",
        "//submodules/TextFormat",
        "//submodules/LocalizedPeerData",
        "//submodules/UrlEscaping",
        "//submodules/PhotoResources",
        "//submodules/TelegramStringFormatting",
        "//submodules/MediaPlayer:UniversalMediaPlayer",
        "//submodules/TelegramUniversalVideoContent",
        "//submodules/GalleryUI",
        "//submodules/WallpaperBackgroundNode",
        "//submodules/InvisibleInkDustNode",
        "//submodules/TelegramUI/Components/TextNodeWithEntities",
        "//submodules/TelegramUI/Components/Chat/ChatMessageBubbleContentNode",
        "//submodules/TelegramUI/Components/Chat/ChatMessageItemCommon",
        "//submodules/Markdown",
        "//submodules/ComponentFlow",
        "//submodules/ReactionSelectionNode",
        "//submodules/Components/MultilineTextComponent",
    ],
    visibility = [
        "//visibility:public",
    ],
)
