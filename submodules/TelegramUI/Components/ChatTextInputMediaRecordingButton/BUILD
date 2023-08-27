load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ChatTextInputMediaRecordingButton",
    module_name = "ChatTextInputMediaRecordingButton",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Display",
        "//submodules/AsyncDisplayKit",
        "//submodules/TelegramCore",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/TelegramPresentationData",
        "//submodules/LegacyComponents",
        "//submodules/AccountContext",
        "//submodules/ChatInterfaceState",
        "//submodules/AudioBlob",
        "//submodules/ChatPresentationInterfaceState",
        "//submodules/ComponentFlow",
        "//submodules/Components/LottieAnimationComponent",
        "//submodules/TelegramUI/Components/LottieComponent",
        "//submodules/TelegramUI/Components/LegacyInstantVideoController",
    ],
    visibility = [
        "//visibility:public",
    ],
)
