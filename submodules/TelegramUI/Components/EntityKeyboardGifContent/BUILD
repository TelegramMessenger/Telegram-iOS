load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "EntityKeyboardGifContent",
    module_name = "EntityKeyboardGifContent",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/Display:Display",
        "//submodules/ComponentFlow:ComponentFlow",
        "//submodules/Components/PagerComponent:PagerComponent",
        "//submodules/Components/BlurredBackgroundComponent:BlurredBackgroundComponent",
        "//submodules/Components/ComponentDisplayAdapters:ComponentDisplayAdapters",
        "//submodules/Components/BundleIconComponent:BundleIconComponent",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/Postbox:Postbox",
        "//submodules/AnimatedStickerNode:AnimatedStickerNode",
        "//submodules/TelegramAnimatedStickerNode:TelegramAnimatedStickerNode",
        "//submodules/YuvConversion:YuvConversion",
        "//submodules/AccountContext:AccountContext",
        "//submodules/SoftwareVideo:SoftwareVideo",
        "//submodules/ShimmerEffect:ShimmerEffect",
        "//submodules/PhotoResources:PhotoResources",
        "//submodules/StickerResources:StickerResources",
        "//submodules/AppBundle:AppBundle",
        "//submodules/Components/MultilineTextComponent:MultilineTextComponent",
        "//submodules/Components/SolidRoundedButtonComponent:SolidRoundedButtonComponent",
        "//submodules/Components/LottieAnimationComponent:LottieAnimationComponent",
        "//submodules/LocalizedPeerData:LocalizedPeerData",
        "//submodules/TelegramNotices:TelegramNotices",
        "//submodules/TelegramUI/Components/MultiplexedVideoNode:MultiplexedVideoNode",
        "//submodules/TelegramUI/Components/EntityKeyboard:EntityKeyboard",
    ],
    visibility = [
        "//visibility:public",
    ],
)
