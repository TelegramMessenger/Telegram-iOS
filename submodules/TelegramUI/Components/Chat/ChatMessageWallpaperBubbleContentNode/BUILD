load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ChatMessageWallpaperBubbleContentNode",
    module_name = "ChatMessageWallpaperBubbleContentNode",
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
        "//submodules/TelegramStringFormatting",
        "//submodules/WallpaperBackgroundNode",
        "//submodules/PhotoResources",
        "//submodules/WallpaperResources",
        "//submodules/Markdown",
        "//submodules/RadialStatusNode",
        "//submodules/ComponentFlow",
        "//submodules/PresentationDataUtils",
        "//submodules/TelegramUI/Components/AudioTranscriptionPendingIndicatorComponent",
        "//submodules/TelegramUI/Components/Chat/ChatMessageBubbleContentNode",
        "//submodules/TelegramUI/Components/Chat/ChatMessageItemCommon",
        "//submodules/TelegramUI/Components/WallpaperPreviewMedia",
        "//submodules/TelegramUI/Components/ChatControllerInteraction",
    ],
    visibility = [
        "//visibility:public",
    ],
)
