load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "PeerInfoVisualMediaPaneNode",
    module_name = "PeerInfoVisualMediaPaneNode",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/AsyncDisplayKit",
        "//submodules/TelegramCore",
        "//submodules/Postbox",
        "//submodules/TelegramPresentationData",
        "//submodules/AccountContext",
        "//submodules/ContextUI",
        "//submodules/PhotoResources",
        "//submodules/RadialStatusNode",
        "//submodules/TelegramStringFormatting",
        "//submodules/GridMessageSelectionNode",
        "//submodules/MediaPlayer:UniversalMediaPlayer",
        "//submodules/ListMessageItem",
        "//submodules/ChatMessageInteractiveMediaBadge",
        "//submodules/SparseItemGrid",
        "//submodules/ShimmerEffect",
        "//submodules/DirectMediaImageCache",
        "//submodules/ComponentFlow",
        "//submodules/TelegramNotices",
        "//submodules/TelegramUIPreferences",
        "//submodules/CheckNode",
        "//submodules/AppBundle",
        "//submodules/TelegramUI/Components/ChatControllerInteraction",
        "//submodules/InvisibleInkDustNode",
        "//submodules/MediaPickerUI",
        "//submodules/TelegramUI/Components/Stories/StoryContainerScreen",
        "//submodules/TelegramUI/Components/EmptyStateIndicatorComponent",
    ],
    visibility = [
        "//visibility:public",
    ],
)
