load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load(
    "@build_bazel_rules_apple//apple:resources.bzl",
    "apple_resource_bundle",
    "apple_resource_group",
)
load("//build-system/bazel-utils:plist_fragment.bzl",
    "plist_fragment",
)

filegroup(
    name = "MediaEditorMetalResources",
    srcs = glob([
        "MetalResources/**/*.*",
    ]),
    visibility = ["//visibility:public"],
)

plist_fragment(
    name = "MediaEditorBundleInfoPlist",
    extension = "plist",
    template =
    """
    <key>CFBundleIdentifier</key>
    <string>org.telegram.MediaEditor</string>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleName</key>
    <string>MediaEditor</string>
    """
)

apple_resource_bundle(
    name = "MediaEditorBundle",
    infoplists = [
        ":MediaEditorBundleInfoPlist",
    ],
    resources = [
        ":MediaEditorMetalResources",
    ],
)

swift_library(
    name = "MediaEditor",
    module_name = "MediaEditor",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    data = [
        ":MediaEditorBundle",
    ],
    deps = [
        "//submodules/AsyncDisplayKit",
        "//submodules/Display",
        "//submodules/Postbox",
        "//submodules/TelegramCore",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/TelegramPresentationData",
        "//submodules/TelegramUIPreferences",
        "//submodules/AccountContext",
        "//submodules/AppBundle",
        "//submodules/TextFormat",
        "//submodules/AnimatedStickerNode",
        "//submodules/TelegramAnimatedStickerNode",
        "//submodules/StickerResources",
        "//submodules/YuvConversion",
        "//submodules/FastBlur",
        "//submodules/WallpaperBackgroundNode",
        "//submodules/ImageTransparency",
        "//submodules/FFMpegBinding",
        "//submodules/TelegramUI/Components/AnimationCache/ImageDCT",
        "//submodules/FileMediaResourceStatus",
        "//submodules/TelegramUI/Components/MediaEditor/ImageObjectSeparation",
    ],
    visibility = [
        "//visibility:public",
    ],
)
