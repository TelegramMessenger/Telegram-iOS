load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "StoryPeerListComponent",
    module_name = "StoryPeerListComponent",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Display",
        "//submodules/ComponentFlow",
        "//submodules/AppBundle",
        "//submodules/Components/BundleIconComponent",
        "//submodules/AccountContext",
        "//submodules/TelegramCore",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/TelegramPresentationData",
        "//submodules/AvatarNode",
        "//submodules/ContextUI",
        "//submodules/TelegramUI/Components/Stories/StoryContainerScreen",
        "//submodules/Components/MultilineTextComponent",
        "//submodules/TelegramUI/Components/EmojiStatusComponent",
        "//submodules/Components/HierarchyTrackingLayer",
        "//submodules/TelegramUI/Components/ChatListTitleView",
    ],
    visibility = [
        "//visibility:public",
    ],
)
