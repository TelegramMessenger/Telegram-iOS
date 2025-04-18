load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "QuickReactionSetupController",
    module_name = "QuickReactionSetupController",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/AccountContext",
        "//submodules/TelegramUI/Components/AnimationCache",
        "//submodules/AsyncDisplayKit",
        "//submodules/ComponentFlow",
        "//submodules/Display",
        "//submodules/TelegramUI/Components/EmojiStatusComponent",
        "//submodules/TelegramUI/Components/EmojiStatusSelectionComponent",
        "//submodules/TelegramUI/Components/EntityKeyboard",
        "//submodules/ItemListUI",
        "//submodules/Postbox",
        "//submodules/PresentationDataUtils",
        "//submodules/Components/ReactionImageComponent",
        "//submodules/ReactionSelectionNode",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/TelegramCore",
        "//submodules/TelegramPresentationData",
        "//submodules/TelegramUIPreferences",
        "//submodules/WallpaperBackgroundNode",
        "//submodules/WebPBinding",
    ],
    visibility = [
        "//visibility:public",
    ],
)
