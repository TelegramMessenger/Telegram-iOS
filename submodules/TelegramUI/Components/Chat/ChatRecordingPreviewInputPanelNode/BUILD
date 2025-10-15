load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ChatRecordingPreviewInputPanelNode",
    module_name = "ChatRecordingPreviewInputPanelNode",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/AsyncDisplayKit",
        "//submodules/Display",
        "//submodules/TelegramCore",
        "//submodules/Postbox",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/TelegramPresentationData",
        "//submodules/MediaPlayer:UniversalMediaPlayer",
        "//submodules/AppBundle",
        "//submodules/ContextUI",
        "//submodules/AnimationUI",
        "//submodules/ManagedAnimationNode",
        "//submodules/ChatPresentationInterfaceState",
        "//submodules/TelegramUI/Components/ChatSendButtonRadialStatusNode",
        "//submodules/TelegramUI/Components/AudioWaveformNode",
        "//submodules/TelegramUI/Components/Chat/ChatInputPanelNode",
        "//submodules/TooltipUI",
        "//submodules/TelegramNotices",
        "//submodules/ComponentFlow",
        "//submodules/Components/ComponentDisplayAdapters",
        "//submodules/TelegramUI/Components/MediaScrubberComponent",
        "//submodules/AnimatedCountLabelNode",
        "//submodules/TelegramUI/Components/Chat/ChatRecordingViewOnceButtonNode",
        "//submodules/TelegramUI/Components/GlassBackgroundComponent",
    ],
    visibility = [
        "//visibility:public",
    ],
)
