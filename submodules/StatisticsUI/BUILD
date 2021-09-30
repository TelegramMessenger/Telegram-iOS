load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "StatisticsUI",
    module_name = "StatisticsUI",
    srcs = glob([
		"Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/Display:Display",
        "//submodules/Postbox:Postbox",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/TelegramUIPreferences:TelegramUIPreferences",
        "//submodules/AccountContext:AccountContext",
        "//submodules/ItemListUI:ItemListUI",
        "//submodules/AvatarNode:AvatarNode",
        "//submodules/TelegramStringFormatting:TelegramStringFormatting",
        "//submodules/AlertUI:AlertUI",
        "//submodules/PresentationDataUtils:PresentationDataUtils",
        "//submodules/MergeLists:MergeLists",
        "//submodules/PhotoResources:PhotoResources",
        "//submodules/GraphCore:GraphCore",
        "//submodules/GraphUI:GraphUI",
        "//submodules/AnimatedStickerNode:AnimatedStickerNode",
        "//submodules/TelegramAnimatedStickerNode:TelegramAnimatedStickerNode",
        "//submodules/ItemListPeerItem:ItemListPeerItem",
        "//submodules/ItemListPeerActionItem:ItemListPeerActionItem",
        "//submodules/ContextUI:ContextUI",
    ],
    visibility = [
        "//visibility:public",
    ],
)
