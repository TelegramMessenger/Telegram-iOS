load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "CommunityRequestsScreen",
    module_name = "CommunityRequestsScreen",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/AccountContext",
        "//submodules/AnimatedStickerNode",
        "//submodules/TelegramUI/Components/ButtonComponent",
        "//submodules/ComponentFlow",
        "//submodules/Components/MultilineTextComponent",
        "//submodules/Components/ViewControllerComponent",
        "//submodules/Display",
        "//submodules/Markdown",
        "//submodules/TelegramUI/Components/EdgeEffect",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/TelegramCore",
        "//submodules/TelegramAnimatedStickerNode",
        "//submodules/TelegramPresentationData",
        "//submodules/TelegramUI/Components/AlertComponent",
        "//submodules/TelegramUI/Components/Communities/CommunityEditScreen",
        "//submodules/TelegramUI/Components/Communities/CommunityPrivateChatScreen",
        "//submodules/TelegramUI/Components/ListSectionComponent",
        "//submodules/TelegramUI/Components/Stories/PeerListItemComponent",
        "//submodules/UndoUI",
    ],
    visibility = [
        "//visibility:public",
    ],
)
