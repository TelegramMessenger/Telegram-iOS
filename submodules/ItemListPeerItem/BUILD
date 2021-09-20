load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ItemListPeerItem",
    module_name = "ItemListPeerItem",
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
        "//submodules/AvatarNode:AvatarNode",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/TelegramStringFormatting:TelegramStringFormatting",
        "//submodules/PeerPresenceStatusManager:PeerPresenceStatusManager",
        "//submodules/ItemListUI:ItemListUI",
        "//submodules/TelegramUIPreferences:TelegramUIPreferences",
        "//submodules/ContextUI:ContextUI",
        "//submodules/PresentationDataUtils:PresentationDataUtils",
        "//submodules/AccountContext:AccountContext",
    ],
    visibility = [
        "//visibility:public",
    ],
)
