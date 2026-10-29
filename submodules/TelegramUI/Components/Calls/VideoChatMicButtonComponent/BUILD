load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "VideoChatMicButtonComponent",
    module_name = "VideoChatMicButtonComponent",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Display",
        "//submodules/ComponentFlow",
        "//submodules/Components/MultilineTextComponent",
        "//submodules/TelegramPresentationData",
        "//submodules/TelegramUI/Components/LottieComponent",
        "//submodules/TelegramUI/Components/Calls/VoiceChatActionButton",
        "//submodules/TelegramUI/Components/Calls/CallScreen",
        "//submodules/MetalEngine",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/AccountContext",
        "//submodules/RadialStatusNode",
        "//submodules/TelegramUI/Components/GlassBackgroundComponent",
        "//submodules/TelegramCore",
    ],
    visibility = [
        "//visibility:public",
    ],
)
