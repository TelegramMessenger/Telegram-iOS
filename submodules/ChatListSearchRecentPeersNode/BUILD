load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ChatListSearchRecentPeersNode",
    module_name = "ChatListSearchRecentPeersNode",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/Display:Display",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/ListSectionHeaderNode:ListSectionHeaderNode",
        "//submodules/HorizontalPeerItem:HorizontalPeerItem",
        "//submodules/MergeLists:MergeLists",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/ContextUI:ContextUI",
        "//submodules/AccountContext:AccountContext",
    ],
    visibility = [
        "//visibility:public",
    ],
)
