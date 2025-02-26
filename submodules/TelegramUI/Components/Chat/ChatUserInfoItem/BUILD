load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ChatUserInfoItem",
    module_name = "ChatUserInfoItem",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Display",
        "//submodules/AsyncDisplayKit",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/Postbox",
        "//submodules/TelegramCore",
        "//submodules/TelegramPresentationData",
        "//submodules/TextFormat",
        "//submodules/UrlEscaping",
        "//submodules/PhotoResources",
        "//submodules/AccountContext",
        "//submodules/MediaPlayer:UniversalMediaPlayer",
        "//submodules/TelegramUniversalVideoContent",
        "//submodules/WallpaperBackgroundNode",
        "//submodules/TelegramUI/Components/ChatControllerInteraction",
        "//submodules/TelegramUI/Components/Chat/ChatMessageBubbleContentNode",
        "//submodules/CountrySelectionUI",
        "//submodules/TelegramStringFormatting",
        "//submodules/TelegramUI/Components/Chat/MergedAvatarsNode",
        "//submodules/TelegramUI/Components/TextNodeWithEntities",
    ],
    visibility = [
        "//visibility:public",
    ],
)
