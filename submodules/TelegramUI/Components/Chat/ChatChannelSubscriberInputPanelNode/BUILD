load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ChatChannelSubscriberInputPanelNode",
    module_name = "ChatChannelSubscriberInputPanelNode",
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
        "//submodules/AlertUI",
        "//submodules/PresentationDataUtils",
        "//submodules/UndoUI",
        "//submodules/ChatPresentationInterfaceState",
        "//submodules/TelegramUI/Components/Chat/ChatInputPanelNode",
        "//submodules/AccountContext",
        "//submodules/TelegramUI/Components/PeerManagement/OldChannelsController",
        "//submodules/TooltipUI",
    ],
    visibility = [
        "//visibility:public",
    ],
)
