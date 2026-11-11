load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_unit_test")
load("@build_bazel_rules_apple//apple/testing/default_runner:ios_test_runner.bzl", "ios_test_runner")

# The reaction bar's pure geometry (where a bar aligned with a lifted card sits, its tail, item shrinking) and the
# fly-in's icon hand-off rule, kept apart from ReactionSelectionNode so a test target can link them without
# AccountContext.
swift_library(
    name = "ReactionContextGeometry",
    module_name = "ReactionContextGeometry",
    srcs = glob([
        "Geometry/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    visibility = [
        "//visibility:public",
    ],
)

swift_library(
    name = "ReactionSelectionNode",
    module_name = "ReactionSelectionNode",
    srcs = glob([
		"Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        ":ReactionContextGeometry",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/Display:Display",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/AnimatedStickerNode:AnimatedStickerNode",
        "//submodules/TelegramAnimatedStickerNode:TelegramAnimatedStickerNode",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/StickerResources:StickerResources",
        "//submodules/AccountContext:AccountContext",
        "//submodules/Components/ReactionButtonListComponent:ReactionButtonListComponent",
        "//submodules/lottie-ios:Lottie",
        "//submodules/AppBundle:AppBundle",
        "//submodules/AvatarNode:AvatarNode",
        "//submodules/ComponentFlow:ComponentFlow",
        "//submodules/Components/PagerComponent:PagerComponent",
        "//submodules/TelegramUI/Components/EmojiStatusSelectionComponent:EmojiStatusSelectionComponent",
        "//submodules/TelegramUI/Components/EntityKeyboard:EntityKeyboard",
        "//submodules/TelegramUI/Components/AnimationCache:AnimationCache",
        "//submodules/TelegramUI/Components/MultiAnimationRenderer:MultiAnimationRenderer",
        "//submodules/TelegramUI/Components/DCTMultiAnimationRendererImpl:DCTMultiAnimationRendererImpl",
        "//submodules/TelegramUI/Components/EmojiTextAttachmentView:EmojiTextAttachmentView",
        "//submodules/Components/ComponentDisplayAdapters:ComponentDisplayAdapters",
        "//submodules/TextFormat:TextFormat",
        "//submodules/GZip:GZip",
        "//submodules/ShimmerEffect:ShimmerEffect",
        "//submodules/TelegramUI/Components/Utils/GenerateStickerPlaceholderImage",
        "//submodules/Components/BalancedTextComponent",
        "//submodules/Markdown",
        "//submodules/TelegramUI/Components/Premium/PremiumStarComponent",
        "//submodules/TelegramUI/Components/GlassBackgroundComponent",
    ],
    visibility = [
        "//visibility:public",
    ],
)

swift_library(
    name = "ReactionContextGeometryTestsLib",
    testonly = True,
    srcs = glob([
        "Tests/**/*.swift",
    ]),
    deps = [
        ":ReactionContextGeometry",
    ],
)

# The runner MUST pin a real device/OS: the default runner picks an invalid
# device and the test process exits 15. Matches //submodules/TelegramPresentationData:TelegramPresentationDataTests.
ios_test_runner(
    name = "ReactionContextGeometryTestRunner",
    device_type = "iPhone 17",
    os_version = "26.5",
)

ios_unit_test(
    name = "ReactionContextGeometryTests",
    minimum_os_version = "15.0",
    runner = ":ReactionContextGeometryTestRunner",
    deps = [
        ":ReactionContextGeometryTestsLib",
    ],
    visibility = [
        "//visibility:public",
    ],
)
