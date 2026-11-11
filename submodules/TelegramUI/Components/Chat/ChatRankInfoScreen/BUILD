load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ChatRankInfoScreen",
    module_name = "ChatRankInfoScreen",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/AsyncDisplayKit",
        "//submodules/Display",
        "//submodules/TelegramPresentationData",
        "//submodules/ChatPresentationInterfaceState",
        "//submodules/AccountContext",
        "//submodules/ComponentFlow",
        "//submodules/ContextUI",
        "//submodules/AppBundle",
        "//submodules/Components/ViewControllerComponent",
        "//submodules/Components/ComponentDisplayAdapters",
        "//submodules/TelegramCore",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/Components/MultilineTextComponent",
        "//submodules/Components/BalancedTextComponent",
        "//submodules/TelegramUI/Components/ButtonComponent",
        "//submodules/TelegramUI/Components/PlainButtonComponent",
        "//submodules/Markdown",
        "//submodules/Components/BundleIconComponent",
        "//submodules/TextFormat",
        "//submodules/TelegramStringFormatting",
        "//submodules/TelegramUI/Components/RankChatPreviewItem",
        "//submodules/TelegramUI/Components/ListSectionComponent",
        "//submodules/TelegramUI/Components/ListItemComponentAdaptor",
    ],
    visibility = [
        "//visibility:public",
    ],
)
