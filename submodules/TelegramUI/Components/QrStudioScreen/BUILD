load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load("@build_bazel_rules_apple//apple:resources.bzl", "apple_resource_bundle")
load("//build-system/bazel-utils:plist_fragment.bzl", "plist_fragment")

filegroup(
    name = "QrStudioMetalSources",
    srcs = glob(["Metal/**/*.metal"]),
    visibility = ["//visibility:public"],
)

plist_fragment(
    name = "QrStudioMetalSourcesBundleInfoPlist",
    extension = "plist",
    template =
    """
    <key>CFBundleIdentifier</key>
    <string>org.telegram.QrStudioMetalSources</string>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleName</key>
    <string>QrStudio</string>
    """
)

apple_resource_bundle(
    name = "QrStudioMetalSourcesBundle",
    infoplists = [":QrStudioMetalSourcesBundleInfoPlist"],
    resources = [":QrStudioMetalSources"],
)

swift_library(
    name = "QrStudioScreen",
    module_name = "QrStudioScreen",
    srcs = glob(["Sources/**/*.swift"]),
    copts = ["-warnings-as-errors"],
    data = [":QrStudioMetalSourcesBundle"],
    deps = [
        "//submodules/AccountContext",
        "//submodules/ComponentFlow",
        "//submodules/Components/BundleIconComponent",
        "//submodules/Components/ComponentDisplayAdapters",
        "//submodules/Components/ViewControllerComponent",
        "//submodules/Display",
        "//submodules/MetalEngine",
        "//submodules/QrCode",
        "//submodules/QrCodeUI",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/TelegramCore",
        "//submodules/TelegramPresentationData",
        "//submodules/TelegramUIPreferences",
        "//submodules/TelegramUI/Components/AnimationCache",
        "//submodules/TelegramUI/Components/EmojiTextAttachmentView",
        "//submodules/TextFormat",
        "//submodules/TelegramUI/Components/AnimatedTextComponent",
        "//submodules/TelegramUI/Components/EmojiStatusSelectionComponent",
        "//submodules/TelegramUI/Components/EntityKeyboard",
        "//submodules/TelegramUI/Components/Utils/GenerateStickerPlaceholderImage",
        "//submodules/TelegramUI/Components/GlassBackgroundComponent",
        "//submodules/TelegramUI/Components/NavigationExpansionTransition",
        "//submodules/TelegramUI/Components/GlassBarButtonComponent",
        "//submodules/TelegramUI/Components/Gifts/GiftItemComponent",
        "//submodules/ContextUI",
        "//submodules/UIKitRuntimeUtils",
        "//submodules/DeviceAccess",
        "//submodules/WallpaperResources",
        "//submodules/LottieBinding",
        "//submodules/LottieSettings",
        "//submodules/GZip",
        "//submodules/AppBundle",
        "//submodules/WallpaperBackgroundNode",
        "//submodules/Components/LottieAnimationComponent",
        "//submodules/TelegramUI/Components/LottieComponent",
        "//submodules/TelegramUI/Components/MultiAnimationRenderer",
    ],
    visibility = ["//visibility:public"],
)
