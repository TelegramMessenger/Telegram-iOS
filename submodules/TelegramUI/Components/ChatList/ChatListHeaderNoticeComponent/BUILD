load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ChatListHeaderNoticeComponent",
    module_name = "ChatListHeaderNoticeComponent",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/AsyncDisplayKit",
        "//submodules/Display",
        "//submodules/TelegramCore",
        "//submodules/TelegramPresentationData",
        "//submodules/AccountContext",
        "//submodules/ComponentFlow",
        "//submodules/Components/ComponentDisplayAdapters",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/AppBundle",
        "//submodules/ItemListUI",
        "//submodules/Markdown",
        "//submodules/TelegramUI/Components/Chat/MergedAvatarsNode",
        "//submodules/TelegramUI/Components/TextNodeWithEntities",
        "//submodules/TextFormat",
        "//submodules/AvatarNode",
        "//submodules/TelegramUI/Components/GlobalControlPanelsContext",
    ],
    visibility = [
        "//visibility:public",
    ],
)
