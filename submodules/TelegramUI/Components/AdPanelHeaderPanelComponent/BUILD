load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "AdPanelHeaderPanelComponent",
    module_name = "AdPanelHeaderPanelComponent",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Display",
        "//submodules/AsyncDisplayKit",
        "//submodules/TelegramPresentationData",
        "//submodules/AccountContext",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/Postbox",
        "//submodules/TelegramCore",
        "//submodules/TelegramUIPreferences",
        "//submodules/StickerResources",
        "//submodules/PhotoResources",
        "//submodules/TelegramStringFormatting",
        "//submodules/AnimatedCountLabelNode",
        "//submodules/AnimatedNavigationStripeNode",
        "//submodules/ContextUI",
        "//submodules/RadialStatusNode",
        "//submodules/TextFormat",
        "//submodules/TelegramUI/Components/TextNodeWithEntities",
        "//submodules/TranslateUI",

    ],
    visibility = [
        "//visibility:public",
    ],
)
