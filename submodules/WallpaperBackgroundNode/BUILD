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
    name = "WallpaperBackgroundNodeMetalResources",
    srcs = glob([
        "Resources/**/*.metal",
    ]),
    visibility = ["//visibility:public"],
)

plist_fragment(
    name = "WallpaperBackgroundNodeBundleInfoPlist",
    extension = "plist",
    template =
    """
    <key>CFBundleIdentifier</key>
    <string>org.telegram.WallpaperBackgroundNode</string>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleName</key>
    <string>WallpaperBackgroundNode</string>
    """
)

apple_resource_bundle(
    name = "WallpaperBackgroundNodeBundle",
    infoplists = [
        ":WallpaperBackgroundNodeBundleInfoPlist",
    ],
    resources = [
        ":WallpaperBackgroundNodeMetalResources",
    ],
)

swift_library(
    name = "WallpaperBackgroundNode",
    module_name = "WallpaperBackgroundNode",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    data = [
        ":WallpaperBackgroundNodeBundle",
    ],
    deps = [
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/Display:Display",
        "//submodules/GradientBackground:GradientBackground",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/AccountContext:AccountContext",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/WallpaperResources:WallpaperResources",
        "//submodules/FastBlur:FastBlur",
        "//submodules/Svg:Svg",
        "//submodules/GZip:GZip",
        "//submodules/AppBundle:AppBundle",
        "//submodules/AnimatedStickerNode:AnimatedStickerNode",
        "//submodules/TelegramAnimatedStickerNode:TelegramAnimatedStickerNode",
        "//submodules/Components/HierarchyTrackingLayer:HierarchyTrackingLayer",
    ],
    visibility = [
        "//visibility:public",
    ],
)
