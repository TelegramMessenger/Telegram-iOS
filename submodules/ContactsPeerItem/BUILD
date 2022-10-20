load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ContactsPeerItem",
    module_name = "ContactsPeerItem",
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
        "//submodules/AccountContext:AccountContext",
        "//submodules/AvatarNode:AvatarNode",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/CheckNode:CheckNode",
        "//submodules/TelegramStringFormatting:TelegramStringFormatting",
        "//submodules/ItemListPeerItem:ItemListPeerItem",
        "//submodules/PeerPresenceStatusManager:PeerPresenceStatusManager",
        "//submodules/ItemListUI:ItemListUI",
        "//submodules/TelegramUIPreferences:TelegramUIPreferences",
        "//submodules/ListSectionHeaderNode:ListSectionHeaderNode",
        "//submodules/ContextUI:ContextUI",
        "//submodules/PresentationDataUtils:PresentationDataUtils",
        "//submodules/ComponentFlow",
        "//submodules/TelegramUI/Components/AnimationCache",
        "//submodules/TelegramUI/Components/MultiAnimationRenderer",
        "//submodules/TelegramUI/Components/EmojiStatusComponent",
    ],
    visibility = [
        "//visibility:public",
    ],
)
