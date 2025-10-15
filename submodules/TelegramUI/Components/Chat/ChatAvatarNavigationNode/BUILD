load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ChatAvatarNavigationNode",
    module_name = "ChatAvatarNavigationNode",
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
        "//submodules/AvatarNode",
        "//submodules/ContextUI",
        "//submodules/TelegramPresentationData",
        "//submodules/TelegramUniversalVideoContent",
        "//submodules/MediaPlayer:UniversalMediaPlayer",
        "//submodules/GalleryUI",
        "//submodules/Components/HierarchyTrackingLayer",
        "//submodules/AccountContext",
        "//submodules/ComponentFlow",
        "//submodules/TelegramUI/Components/EmojiStatusComponent",
        "//submodules/AvatarVideoNode",
        "//submodules/TelegramUI/Components/Stories/AvatarStoryIndicatorComponent",
        "//submodules/Components/ComponentDisplayAdapters",
    ],
    visibility = [
        "//visibility:public",
    ],
)
