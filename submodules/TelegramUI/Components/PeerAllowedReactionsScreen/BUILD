load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "PeerAllowedReactionsScreen",
    module_name = "PeerAllowedReactionsScreen",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Display:Display",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/ComponentFlow",
        "//submodules/Components/ComponentDisplayAdapters",
        "//submodules/AppBundle",
        "//submodules/Components/ViewControllerComponent",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/TelegramCore",
        "//submodules/Postbox",
        "//submodules/AccountContext",
        "//submodules/TelegramUI/Components/EntityKeyboard",
        "//submodules/TelegramUI/Components/SwitchComponent",
        "//submodules/Components/MultilineTextComponent",
        "//submodules/Markdown",
        "//submodules/TelegramUI/Components/ButtonComponent",
        "//submodules/TelegramUI/Components/AnimatedTextComponent",
        "//submodules/TelegramUI/Components/PremiumLockButtonSubtitleComponent",
        "//submodules/Components/BundleIconComponent",
        "//submodules/Components/PagerComponent",
        "//submodules/PremiumUI",
        "//submodules/UndoUI",
        "//submodules/TextFormat",
        "//submodules/Components/HierarchyTrackingLayer",
        "//submodules/TelegramUI/Components/ListSectionComponent",
        "//submodules/TelegramUI/Components/ListItemSliderSelectorComponent",
        "//submodules/TelegramUI/Components/ListSwitchItemComponent",
    ],
    visibility = [
        "//visibility:public",
    ],
)
