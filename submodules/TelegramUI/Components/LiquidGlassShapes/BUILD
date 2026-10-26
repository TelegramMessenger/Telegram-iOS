load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load(
    "@build_bazel_rules_apple//apple:resources.bzl",
    "apple_resource_bundle",
)
load(
    "//build-system/bazel-utils:plist_fragment.bzl",
    "plist_fragment",
)

filegroup(
    name = "LiquidGlassShapesMetalSources",
    srcs = glob([
        "Metal/**/*.metal",
    ]),
    visibility = ["//visibility:public"],
)

plist_fragment(
    name = "LiquidGlassShapesMetalSourcesBundleInfoPlist",
    extension = "plist",
    template =
    """
    <key>CFBundleIdentifier</key>
    <string>org.telegram.LiquidGlassShapesMetalSources</string>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleName</key>
    <string>LiquidGlassShapes</string>
    """
)

apple_resource_bundle(
    name = "LiquidGlassShapesMetalSourcesBundle",
    infoplists = [
        ":LiquidGlassShapesMetalSourcesBundleInfoPlist",
    ],
    resources = [
        ":LiquidGlassShapesMetalSources",
    ],
)

swift_library(
    name = "LiquidGlassShapes",
    module_name = "LiquidGlassShapes",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    data = [
        ":LiquidGlassShapesMetalSourcesBundle",
    ],
    deps = [
        "//submodules/Display",
        "//submodules/MetalEngine",
        "//submodules/TelegramUI/Components/GlassBackgroundComponent",
    ],
    visibility = [
        "//visibility:public",
    ],
)
