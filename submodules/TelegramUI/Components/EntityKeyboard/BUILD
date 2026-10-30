load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_unit_test")
load("@build_bazel_rules_apple//apple/testing/default_runner:ios_test_runner.bzl", "ios_test_runner")

swift_library(
    name = "EntityKeyboard",
    module_name = "EntityKeyboard",
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
        "//submodules/TelegramUI/Components/AnimationCache:AnimationCache",
        "//submodules/TelegramUI/Components/LottieAnimationCache:LottieAnimationCache",
        "//submodules/TelegramUI/Components/VideoAnimationCache:VideoAnimationCache",
        "//submodules/TelegramUI/Components/MultiAnimationRenderer:MultiAnimationRenderer",
        "//submodules/TelegramUI/Components/DCTMultiAnimationRendererImpl:DCTMultiAnimationRendererImpl",
        "//submodules/TelegramUI/Components/EmojiTextAttachmentView:EmojiTextAttachmentView",
        "//submodules/TelegramUI/Components/EmojiStatusComponent:EmojiStatusComponent",
        "//submodules/TelegramUI/Components/LottieComponent",
        "//submodules/TelegramUI/Components/LottieComponentEmojiContent",
        "//submodules/SoftwareVideo:SoftwareVideo",
        "//submodules/ShimmerEffect:ShimmerEffect",
        "//submodules/PhotoResources:PhotoResources",
        "//submodules/StickerResources:StickerResources",
        "//submodules/AppBundle:AppBundle",
        "//submodules/UndoUI:UndoUI",
        "//submodules/Components/MultilineTextComponent:MultilineTextComponent",
        "//submodules/TelegramUI/Components/ButtonComponent",
        "//submodules/Components/LottieAnimationComponent:LottieAnimationComponent",
        "//submodules/LocalizedPeerData:LocalizedPeerData",
        "//submodules/TelegramNotices:TelegramNotices",
        "//submodules/GZip",
        "//submodules/LottieBinding:LottieBinding",
        "//submodules/lottie-ios:Lottie",
        "//submodules/TelegramUI/Components/Utils/GenerateStickerPlaceholderImage",
        "//submodules/TelegramUIPreferences",
        "//submodules/TelegramCore/FlatBuffers",
        "//submodules/TelegramCore/FlatSerialization",
        "//submodules/TelegramUI/Components/BatchVideoRendering",
        "//submodules/TelegramUI/Components/GifVideoLayer",
        "//submodules/TelegramUI/Components/GlassBackgroundComponent",
        "//submodules/TelegramUI/Components/EdgeEffect",
        "//submodules/TelegramUI/Components/LiquidLens",
        "//submodules/TelegramUI/Components/TabSelectionRecognizer",
    ],
    visibility = [
        "//visibility:public",
    ],
)

swift_library(
    name = "EntityKeyboardTestsLib",
    testonly = True,
    srcs = glob([
        "Tests/**/*.swift",
    ]),
    deps = [
        ":EntityKeyboard",
        "//submodules/Display:Display",
    ],
)

ios_test_runner(
    name = "EntityKeyboardTestRunner",
    device_type = "iPhone 17",
    os_version = "26.5",
)

ios_unit_test(
    name = "EntityKeyboardTests",
    minimum_os_version = "15.0",
    runner = ":EntityKeyboardTestRunner",
    deps = [
        ":EntityKeyboardTestsLib",
    ],
    visibility = [
        "//visibility:public",
    ],
)
