load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "MessageInputActionButtonComponent",
    module_name = "MessageInputActionButtonComponent",
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
        "//submodules/TelegramUI/Components/ChatTextInputMediaRecordingButton",
        "//submodules/AccountContext",
        "//submodules/TelegramPresentationData",
        "//submodules/ChatPresentationInterfaceState",
        "//submodules/TelegramUI/Components/MoreHeaderButton",
        "//submodules/ContextUI",
        "//submodules/Components/ReactionButtonListComponent",
        "//submodules/TelegramCore",
        "//submodules/TelegramUI/Components/GlassBackgroundComponent",
    ],
    visibility = [
        "//visibility:public",
    ],
)
