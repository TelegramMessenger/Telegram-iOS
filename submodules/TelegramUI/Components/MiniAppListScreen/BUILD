load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "MiniAppListScreen",
    module_name = "MiniAppListScreen",
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
        "//submodules/Postbox",
        "//submodules/TelegramCore",
        "//submodules/TelegramPresentationData",
        "//submodules/TelegramUIPreferences",
        "//submodules/PresentationDataUtils",
        "//submodules/AccountContext",
        "//submodules/ComponentFlow",
        "//submodules/Components/ViewControllerComponent",
        "//submodules/MergeLists",
        "//submodules/Components/ComponentDisplayAdapters",
        "//submodules/ItemListUI",
        "//submodules/ChatListUI",
        "//submodules/ItemListPeerItem",
        "//submodules/TelegramUI/Components/ChatListHeaderComponent",
        "//submodules/TelegramUI/Components/PlainButtonComponent",
        "//submodules/Components/MultilineTextComponent",
        "//submodules/SearchBarNode",
        "//submodules/Components/BalancedTextComponent",
        "//submodules/ChatListSearchItemHeader",
    ],
    visibility = [
        "//visibility:public",
    ],
)
