load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ChatBotInfoItem",
    module_name = "ChatBotInfoItem",
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
    ],
    visibility = [
        "//visibility:public",
    ],
)
