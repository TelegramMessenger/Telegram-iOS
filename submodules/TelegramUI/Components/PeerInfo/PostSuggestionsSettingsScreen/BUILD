load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "PostSuggestionsSettingsScreen",
    module_name = "PostSuggestionsSettingsScreen",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Display",
        "//submodules/TelegramPresentationData",
        "//submodules/ComponentFlow",
        "//submodules/Components/ComponentDisplayAdapters",
        "//submodules/AppBundle",
        "//submodules/Components/ViewControllerComponent",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/TelegramCore",
        "//submodules/Postbox",
        "//submodules/AccountContext",
        "//submodules/TelegramUI/Components/SwitchComponent",
        "//submodules/Components/MultilineTextComponent",
        "//submodules/Markdown",
        "//submodules/TelegramUI/Components/ButtonComponent",
        "//submodules/Components/BundleIconComponent",
        "//submodules/TextFormat",
        "//submodules/TelegramUI/Components/ListSectionComponent",
        "//submodules/TelegramUI/Components/ListSwitchItemComponent",
        "//submodules/TelegramUI/Components/ListActionItemComponent",
        "//submodules/TelegramStringFormatting",
        "//submodules/TelegramUI/Components/ListItemComponentAdaptor",
        "//submodules/TelegramUI/Components/PeerInfo/MessagePriceItem",
    ],
    visibility = [
        "//visibility:public",
    ],
)
