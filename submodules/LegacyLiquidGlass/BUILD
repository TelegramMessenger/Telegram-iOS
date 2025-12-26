load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load(
    "@build_bazel_rules_apple//apple:resources.bzl",
    "apple_resource_bundle",
)
load("//build-system/bazel-utils:plist_fragment.bzl",
    "plist_fragment",
)

filegroup(
    name = "MetalSources",
    srcs = glob([
        "Source/**/*.metal",
    ]),
    visibility = ["//visibility:public"],
)

plist_fragment(
    name = "LegacyLiquidGlassMetalSourcesBundleInfoPlist",
    extension = "plist",
    template =
    """
    <key>CFBundleIdentifier</key>
    <string>org.telegram.LegacyLiquidGlassMetalSources</string>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleName</key>
    <string>LegacyLiquidGlass</string>
    """
)

apple_resource_bundle(
    name = "LegacyLiquidGlassMetalSourcesBundle",
    infoplists = [
        ":LegacyLiquidGlassMetalSourcesBundleInfoPlist",
    ],
    resources = [
        "Source/ChromaticAberrationFilterLGL.metal",
        "Source/DistortionFilterLGL.metal",
    ],
    structured_resources = glob([
        "Source/**/*.metal",
    ]),
    bundle_id = "org.telegram.LegacyLiquidGlassMetalSources",
    visibility = ["//visibility:public"],
)

swift_library(
    name = "LegacyLiquidGlass",
    module_name = "LegacyLiquidGlass",
    srcs = glob([
        "Source/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
        "-Xfrontend",
        "-warn-long-expression-type-checking=0",
        "-Xfrontend",
        "-suppress-warnings",
    ],
    deps = [
        ":LegacyLiquidGlassMetalSourcesBundle",
    ],
    visibility = [
        "//visibility:public",
    ],
)
