load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "PeerInfoStoryGridScreen",
    module_name = "PeerInfoStoryGridScreen",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/AsyncDisplayKit",
        "//submodules/TelegramCore",
        "//submodules/Postbox",
        "//submodules/TelegramPresentationData",
        "//submodules/AccountContext",
        "//submodules/ComponentFlow",
        "//submodules/Components/ComponentDisplayAdapters",
        "//submodules/Components/ViewControllerComponent",
        "//submodules/TelegramUI/Components/PeerInfo/PeerInfoVisualMediaPaneNode",
        "//submodules/TelegramUI/Components/ChatListHeaderComponent",
        "//submodules/TelegramUI/Components/ChatTitleView",
        "//submodules/ContextUI",
        "//submodules/UndoUI",
        "//submodules/TelegramUI/Components/BottomButtonPanelComponent",
        "//submodules/TelegramUI/Components/MoreHeaderButton",
        "//submodules/TelegramUI/Components/MediaEditorScreen",
        "//submodules/SaveToCameraRoll",
    ],
    visibility = [
        "//visibility:public",
    ],
)
