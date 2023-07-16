load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "FeaturedStickersScreen",
    module_name = "FeaturedStickersScreen",
    srcs = glob([
		"Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Display:Display",
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/Postbox:Postbox",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/AccountContext:AccountContext",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/TelegramUIPreferences:TelegramUIPreferences",
        "//submodules/MergeLists:MergeLists",
        "//submodules/StickerPackPreviewUI:StickerPackPreviewUI",
        "//submodules/StickerPeekUI:StickerPeekUI",
        "//submodules/OverlayStatusController:OverlayStatusController",
        "//submodules/PresentationDataUtils:PresentationDataUtils",
        "//submodules/SearchBarNode:SearchBarNode",
        "//submodules/UndoUI:UndoUI",
        "//submodules/ContextUI:ContextUI",
        "//submodules/PremiumUI:PremiumUI",
        "//submodules/ChatPresentationInterfaceState:ChatPresentationInterfaceState",
        "//submodules/StickerResources:StickerResources",
        "//submodules/AnimatedStickerNode:AnimatedStickerNode",
        "//submodules/TelegramAnimatedStickerNode:TelegramAnimatedStickerNode",
        "//submodules/TelegramUI/Components/EmojiTextAttachmentView",
        "//submodules/TextFormat",
    ],
    visibility = [
        "//visibility:public",
    ],
)
