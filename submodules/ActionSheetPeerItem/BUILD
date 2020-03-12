load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ActionSheetPeerItem",
    module_name = "ActionSheetPeerItem",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//submodules/Postbox:Postbox",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/SyncCore:SyncCore",
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/Display:Display",
        "//submodules/AvatarNode:AvatarNode",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/AccountContext:AccountContext",
    ],
    visibility = [
        "//visibility:public",
    ],
)
