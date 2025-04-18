load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "PeerInfoChatListPaneNode",
    module_name = "PeerInfoChatListPaneNode",
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
        "//submodules/TelegramStringFormatting",
        "//submodules/ShimmerEffect",
        "//submodules/ComponentFlow",
        "//submodules/AppBundle",
        "//submodules/ChatListUI",
        "//submodules/TelegramUI/Components/PeerInfo/PeerInfoPaneNode",
        "//submodules/DeleteChatPeerActionSheetItem",
        "//submodules/UndoUI",
    ],
    visibility = [
        "//visibility:public",
    ],
)
