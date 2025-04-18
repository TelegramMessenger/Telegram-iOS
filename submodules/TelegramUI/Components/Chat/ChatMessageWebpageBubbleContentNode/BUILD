load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ChatMessageWebpageBubbleContentNode",
    module_name = "ChatMessageWebpageBubbleContentNode",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Postbox",
        "//submodules/Display",
        "//submodules/AsyncDisplayKit",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/TelegramCore",
        "//submodules/TelegramUIPreferences",
        "//submodules/TextFormat",
        "//submodules/AccountContext",
        "//submodules/WebsiteType",
        "//submodules/InstantPageUI",
        "//submodules/UrlHandling",
        "//submodules/GalleryData",
        "//submodules/TelegramPresentationData",
        "//submodules/TelegramUI/Components/Chat/ChatMessageBubbleContentNode",
        "//submodules/TelegramUI/Components/Chat/ChatMessageItemCommon",
        "//submodules/TelegramUI/Components/WallpaperPreviewMedia",
        "//submodules/TelegramUI/Components/Chat/ChatMessageInteractiveMediaNode",
        "//submodules/TelegramUI/Components/Chat/ChatMessageAttachedContentNode",
        "//submodules/TelegramUI/Components/Chat/ChatHistoryEntry",
        "//submodules/TelegramUI/Components/ChatControllerInteraction",
    ],
    visibility = [
        "//visibility:public",
    ],
)
