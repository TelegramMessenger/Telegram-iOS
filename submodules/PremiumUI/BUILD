load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "PremiumUI",
    module_name = "PremiumUI",
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
        "//submodules/TelegramStringFormatting:TelegramStringFormatting",
        "//submodules/AppBundle:AppBundle",
        "//submodules/AnimatedStickerNode:AnimatedStickerNode",
        "//submodules/TelegramAnimatedStickerNode:TelegramAnimatedStickerNode",
        "//submodules/SolidRoundedButtonNode:SolidRoundedButtonNode",
        "//submodules/PresentationDataUtils:PresentationDataUtils",
        "//submodules/ReactionSelectionNode:ReactionSelectionNode",
    ],
    visibility = [
        "//visibility:public",
    ],
)
