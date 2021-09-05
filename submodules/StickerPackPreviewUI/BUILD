load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "StickerPackPreviewUI",
    module_name = "StickerPackPreviewUI",
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
        "//submodules/AccountContext:AccountContext",
        "//submodules/TelegramUIPreferences:TelegramUIPreferences",
        "//submodules/ShareController:ShareController",
        "//submodules/StickerResources:StickerResources",
        "//submodules/AlertUI:AlertUI",
        "//submodules/PresentationDataUtils:PresentationDataUtils",
        "//submodules/TextFormat:TextFormat",
        "//submodules/MergeLists:MergeLists",
        "//submodules/ActivityIndicator:ActivityIndicator",
        "//submodules/AnimatedStickerNode:AnimatedStickerNode",
        "//submodules/TelegramAnimatedStickerNode:TelegramAnimatedStickerNode",
        "//submodules/ArchivedStickerPacksNotice:ArchivedStickerPacksNotice",
        "//submodules/ShimmerEffect:ShimmerEffect",
        "//submodules/UndoUI:UndoUI",
        "//submodules/ContextUI:ContextUI",
    ],
    visibility = [
        "//visibility:public",
    ],
)
