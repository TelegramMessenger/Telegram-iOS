load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "MessageInputPanelComponent",
    module_name = "MessageInputPanelComponent",
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
        "//submodules/TelegramUI/Components/TextFieldComponent",
        "//submodules/Components/BundleIconComponent",
        "//submodules/TelegramUI/Components/ChatTextInputMediaRecordingButton",
        "//submodules/TelegramUI/Components/LottieComponent",
        "//submodules/AccountContext",
        "//submodules/TelegramPresentationData",
        "//submodules/ManagedAnimationNode",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/Components/HierarchyTrackingLayer",
        "//submodules/TelegramUI/Components/AudioWaveformComponent",
        "//submodules/MediaPlayer:UniversalMediaPlayer",
    ],
    visibility = [
        "//visibility:public",
    ],
)
