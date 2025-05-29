load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ChatSideTopicsPanel",
    module_name = "ChatSideTopicsPanel",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/Postbox",
        "//submodules/TelegramCore",
        "//submodules/Display",
        "//submodules/AsyncDisplayKit",
        "//submodules/TelegramPresentationData",
        "//submodules/ChatPresentationInterfaceState",
        "//submodules/ComponentFlow",
        "//submodules/Components/MultilineTextComponent",
        "//submodules/AccountContext",
        "//submodules/Components/BlurredBackgroundComponent",
        "//submodules/TelegramUI/Components/EmojiStatusComponent",
        "//submodules/Components/BundleIconComponent",
        "//submodules/AvatarNode",
        "//submodules/ChatListUI",
        "//submodules/ContextUI",
        "//submodules/TelegramUI/Components/AsyncListComponent",
        "//submodules/TelegramUI/Components/TextBadgeComponent",
        "//submodules/TelegramUI/Components/MaskedContainerComponent",
        "//submodules/AppBundle",
        "//submodules/PresentationDataUtils",
    ],
    visibility = [
        "//visibility:public",
    ],
)
