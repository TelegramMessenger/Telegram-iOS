load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ChatMessageCommunityChangedBubbleContentNode",
    module_name = "ChatMessageCommunityChangedBubbleContentNode",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/AccountContext",
        "//submodules/AsyncDisplayKit",
        "//submodules/AvatarNode",
        "//submodules/Display",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/TelegramCore",
        "//submodules/TelegramPresentationData",
        "//submodules/TelegramUIPreferences",
        "//submodules/TextFormat",
        "//submodules/Markdown",
        "//submodules/WallpaperBackgroundNode",
        "//submodules/TelegramUI/Components/Chat/ChatMessageBubbleContentNode",
        "//submodules/TelegramUI/Components/Chat/ChatMessageItemCommon",
        "//submodules/TelegramUI/Components/ChatControllerInteraction",
    ],
    visibility = [
        "//visibility:public",
    ],
)
