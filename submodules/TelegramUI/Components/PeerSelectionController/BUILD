load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "PeerSelectionController",
    module_name = "PeerSelectionController",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/Display",
        "//submodules/TelegramCore",
        "//submodules/Postbox",
        "//submodules/TelegramPresentationData",
        "//submodules/ProgressNavigationButtonNode",
        "//submodules/AccountContext",
        "//submodules/SearchUI",
        "//submodules/ChatListUI",
        "//submodules/SearchBarNode",
        "//submodules/ContactListUI",
        "//submodules/SegmentedControlNode",
        "//submodules/AttachmentTextInputPanelNode",
        "//submodules/ChatPresentationInterfaceState",
        "//submodules/ChatSendMessageActionUI",
        "//submodules/ChatTextLinkEditUI",
        "//submodules/TelegramUI/Components/AnimationCache",
        "//submodules/TelegramUI/Components/MultiAnimationRenderer",
        "//submodules/AnimatedStickerNode",
        "//submodules/TelegramAnimatedStickerNode",
        "//submodules/SolidRoundedButtonNode",
        "//submodules/ContextUI",
        "//submodules/TextFormat",
        "//submodules/TelegramUI/Components/Chat/ForwardAccessoryPanelNode",
        "//submodules/CounterControllerTitleView",
    ],
    visibility = [
        "//visibility:public",
    ],
)
