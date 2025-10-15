load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ChatInlineSearchResultsListComponent",
    module_name = "ChatInlineSearchResultsListComponent",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/AsyncDisplayKit",
        "//submodules/ComponentFlow",
        "//submodules/Display",
        "//submodules/TelegramCore",
        "//submodules/Postbox",
        "//submodules/AccountContext",
        "//submodules/ChatListUI",
        "//submodules/MergeLists",
        "//submodules/Components/ComponentDisplayAdapters",
        "//submodules/TelegramPresentationData",
        "//submodules/TelegramUIPreferences",
        "//submodules/UIKitRuntimeUtils",
        "//submodules/ChatPresentationInterfaceState",
        "//submodules/ContactsPeerItem",
        "//submodules/ItemListUI",
        "//submodules/ChatListSearchItemHeader",
        "//submodules/TelegramUI/Components/LottieComponent",
        "//submodules/Components/MultilineTextComponent",
    ],
    visibility = [
        "//visibility:public",
    ],
)
