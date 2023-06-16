load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "StoryContentComponent",
    module_name = "StoryContentComponent",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Display",
        "//submodules/AsyncDisplayKit",
        "//submodules/ComponentFlow",
        "//submodules/TelegramUI/Components/Stories/StoryContainerScreen",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/AccountContext",
        "//submodules/TelegramCore",
        "//submodules/Postbox",
        "//submodules/PhotoResources",
        "//submodules/MediaPlayer:UniversalMediaPlayer",
        "//submodules/TelegramUniversalVideoContent",
        "//submodules/AvatarNode",
        "//submodules/Components/HierarchyTrackingLayer",
        "//submodules/Utils/VolumeButtons",
    ],
    visibility = [
        "//visibility:public",
    ],
)
