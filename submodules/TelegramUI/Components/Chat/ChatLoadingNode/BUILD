load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ChatLoadingNode",
    module_name = "ChatLoadingNode",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/AsyncDisplayKit",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/Display",
        "//submodules/TelegramCore",
        "//submodules/TelegramPresentationData",
        "//submodules/ActivityIndicator",
        "//submodules/WallpaperBackgroundNode",
        "//submodules/ShimmerEffect",
        "//submodules/ChatPresentationInterfaceState",
        "//submodules/AccountContext",
        "//submodules/TelegramUI/Components/Chat/ChatMessageItem",
        "//submodules/TelegramUI/Components/Chat/ChatMessageItemView",
        "//submodules/TelegramUI/Components/Chat/ChatMessageStickerItemNode",
        "//submodules/TelegramUI/Components/Chat/ChatMessageInstantVideoItemNode",
        "//submodules/TelegramUI/Components/Chat/ChatMessageAnimatedStickerItemNode",
        "//submodules/TelegramUI/Components/Chat/ChatMessageBubbleItemNode",
        "//submodules/TelegramUI/Components/Chat/ChatMessageItemImpl",
    ],
    visibility = [
        "//visibility:public",
    ],
)
