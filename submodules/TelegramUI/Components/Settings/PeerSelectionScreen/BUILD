load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "PeerSelectionScreen",
    module_name = "PeerSelectionScreen",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Display",
        "//submodules/AsyncDisplayKit",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/TelegramCore",
        "//submodules/TelegramPresentationData",
        "//submodules/TelegramUIPreferences",
        "//submodules/MergeLists",
        "//submodules/ItemListUI",
        "//submodules/PresentationDataUtils",
        "//submodules/ContactsPeerItem",
        "//submodules/TelegramUI/Components/ChatListHeaderComponent",
        "//submodules/SearchBarNode",
        "//submodules/Components/ViewControllerComponent",
        "//submodules/ComponentFlow",
        "//submodules/Components/MultilineTextComponent",
        "//submodules/Components/BalancedTextComponent",
        "//submodules/ItemListPeerActionItem",
        "//submodules/AccountContext",
        "//submodules/Components/HierarchyTrackingLayer",
        "//submodules/Components/ComponentDisplayAdapters",
    ],
    visibility = [
        "//visibility:public",
    ],
)
