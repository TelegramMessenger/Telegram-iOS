load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "SuggestPostAccessoryPanelNode",
    module_name = "SuggestPostAccessoryPanelNode",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/AsyncDisplayKit",
        "//submodules/TelegramCore",
        "//submodules/Postbox",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/Display",
        "//submodules/TelegramPresentationData",
        "//submodules/TelegramUIPreferences",
        "//submodules/AccountContext",
        "//submodules/LocalizedPeerData",
        "//submodules/PhotoResources",
        "//submodules/TelegramStringFormatting",
        "//submodules/TextFormat",
        "//submodules/ChatPresentationInterfaceState",
        "//submodules/TelegramUI/Components/TextNodeWithEntities",
        "//submodules/TelegramUI/Components/AnimationCache",
        "//submodules/TelegramUI/Components/MultiAnimationRenderer",
        "//submodules/TelegramUI/Components/Chat/AccessoryPanelNode",
        "//submodules/TelegramUI/Components/CompositeTextNode",
        "//submodules/TelegramNotices",
    ],
    visibility = [
        "//visibility:public",
    ],
)

