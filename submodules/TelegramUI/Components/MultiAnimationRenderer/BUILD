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
    name = "MultiAnimationRendererMetalResources",
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
    <string>org.telegram.MultiAnimationRenderer</string>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleName</key>
    <string>MultiAnimationRenderer</string>
    """
)

apple_resource_bundle(
    name = "MultiAnimationRendererBundle",
    infoplists = [
        ":WallpaperBackgroundNodeBundleInfoPlist",
    ],
    resources = [
        ":MultiAnimationRendererMetalResources",
    ],
)

swift_library(
    name = "MultiAnimationRenderer",
    module_name = "MultiAnimationRenderer",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    data = [
        ":MultiAnimationRendererBundle",
    ],
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/Display:Display",
        "//submodules/TelegramUI/Components/AnimationCache:AnimationCache",
    ],
    visibility = [
        "//visibility:public",
    ],
)
