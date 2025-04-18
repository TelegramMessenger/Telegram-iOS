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
    name = "DustEffectMetalSources",
    srcs = glob([
        "Metal/**/*.metal",
    ]),
    visibility = ["//visibility:public"],
)

plist_fragment(
    name = "DustEffectMetalSourcesBundleInfoPlist",
    extension = "plist",
    template =
    """
    <key>CFBundleIdentifier</key>
    <string>org.telegram.DustEffectMetalSources</string>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleName</key>
    <string>DustEffect</string>
    """
)

apple_resource_bundle(
    name = "DustEffectMetalSourcesBundle",
    infoplists = [
        ":DustEffectMetalSourcesBundleInfoPlist",
    ],
    resources = [
        ":DustEffectMetalSources",
    ],
)

swift_library(
    name = "DustEffect",
    module_name = "DustEffect",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    data = [
        ":DustEffectMetalSourcesBundle",
    ],
    deps = [
        "//submodules/Display",
        "//submodules/MetalEngine",
    ],
    visibility = [
        "//visibility:public",
    ],
)
