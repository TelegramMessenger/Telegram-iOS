load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "StickerPeekUI",
    module_name = "StickerPeekUI",
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
        "//submodules/StickerResources:StickerResources",
        "//submodules/AlertUI:AlertUI",
        "//submodules/PresentationDataUtils:PresentationDataUtils",
        "//submodules/TextFormat:TextFormat",
        "//submodules/ActivityIndicator:ActivityIndicator",
        "//submodules/AnimatedStickerNode:AnimatedStickerNode",
        "//submodules/TelegramAnimatedStickerNode:TelegramAnimatedStickerNode",
        "//submodules/ShimmerEffect:ShimmerEffect",
        "//submodules/ContextUI:ContextUI",
        "//submodules/SolidRoundedButtonNode:SolidRoundedButtonNode",
        "//submodules/PremiumUI:PremiumUI",
    ],
    visibility = [
        "//visibility:public",
    ],
)
