load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ChatBotStartInputPanelNode",
    module_name = "ChatBotStartInputPanelNode",
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
        "//submodules/ChatPresentationInterfaceState",
        "//submodules/SolidRoundedButtonNode",
        "//submodules/TooltipUI",
        "//submodules/TelegramUI/Components/Chat/ChatInputPanelNode",
    ],
    visibility = [
        "//visibility:public",
    ],
)
