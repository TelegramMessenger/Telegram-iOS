load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ChatThemeScreen",
    module_name = "ChatThemeScreen",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/AsyncDisplayKit",
        "//submodules/Display",
        "//submodules/Postbox",
        "//submodules/TelegramCore",
        "//submodules/AccountContext",
        "//submodules/ComponentFlow",
        "//submodules/TelegramPresentationData",
        "//submodules/TelegramUIPreferences",
        "//submodules/PresentationDataUtils",
        "//submodules/TelegramNotices",
        "//submodules/AnimationUI",
        "//submodules/MergeLists",
        "//submodules/MediaResources",
        "//submodules/StickerResources",
        "//submodules/WallpaperResources",
        "//submodules/TooltipUI",
        "//submodules/SolidRoundedButtonNode",
        "//submodules/AnimatedStickerNode",
        "//submodules/TelegramAnimatedStickerNode",
        "//submodules/ShimmerEffect",
        "//submodules/AttachmentUI",
        "//submodules/AvatarNode",
        "//submodules/Markdown",
        "//submodules/AppBundle",
        "//submodules/ActivityIndicator",
        "//submodules/TelegramUI/Components/Gifts/GiftItemComponent",
    ],
    visibility = [
        "//visibility:public",
    ],
)
