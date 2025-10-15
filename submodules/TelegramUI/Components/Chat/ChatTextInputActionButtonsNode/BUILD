load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ChatTextInputActionButtonsNode",
    module_name = "ChatTextInputActionButtonsNode",
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
        "//submodules/TelegramCore",
        "//submodules/TelegramPresentationData",
        "//submodules/ContextUI",
        "//submodules/ChatPresentationInterfaceState",
        "//submodules/ChatMessageBackground",
        "//submodules/TelegramUI/Components/ChatControllerInteraction",
        "//submodules/AccountContext",
        "//submodules/TelegramUI/Components/ChatTextInputMediaRecordingButton",
        "//submodules/TelegramUI/Components/ChatSendButtonRadialStatusNode",
        "//submodules/ChatSendMessageActionUI",
        "//submodules/ComponentFlow",
        "//submodules/AnimatedCountLabelNode",
        "//submodules/TelegramUI/Components/GlassBackgroundComponent",
    ],
    visibility = [
        "//visibility:public",
    ],
)
