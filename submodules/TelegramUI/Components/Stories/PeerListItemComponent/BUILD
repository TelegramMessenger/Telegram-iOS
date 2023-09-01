load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "PeerListItemComponent",
    module_name = "PeerListItemComponent",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Display",
        "//submodules/ComponentFlow",
        "//submodules/TelegramPresentationData",
        "//submodules/AsyncDisplayKit",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/AccountContext",
        "//submodules/TelegramCore",
        "//submodules/Postbox",
        "//submodules/Components/MultilineTextComponent",
        "//submodules/AvatarNode",
        "//submodules/CheckNode",
        "//submodules/TelegramStringFormatting",
        "//submodules/AppBundle",
        "//submodules/PeerPresenceStatusManager",
        "//submodules/TelegramUI/Components/EmojiStatusComponent",
        "//submodules/TelegramUI/Components/EmojiTextAttachmentView",
        "//submodules/ContextUI",
        "//submodules/TextFormat",
    ],
    visibility = [
        "//visibility:public",
    ],
)

