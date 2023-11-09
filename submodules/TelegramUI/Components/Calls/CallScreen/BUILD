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
    name = "MetalSources",
    srcs = glob([
        "Metal/**/*.metal",
    ]),
    visibility = ["//visibility:public"],
)

plist_fragment(
    name = "MetalSourcesBundleInfoPlist",
    extension = "plist",
    template =
    """
    <key>CFBundleIdentifier</key>
    <string>org.telegram.CallScreenMetalSources</string>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleName</key>
    <string>AnimationCompression</string>
    """
)

apple_resource_bundle(
    name = "MetalSourcesBundle",
    infoplists = [
        ":MetalSourcesBundleInfoPlist",
    ],
    resources = [
        ":MetalSources",
    ],
)

swift_library(
    name = "CallScreen",
    module_name = "CallScreen",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    data = [
        ":MetalSourcesBundle",
    ],
    deps = [
        "//submodules/Display",
        "//submodules/ComponentFlow",
        "//submodules/TelegramUI/Components/AnimatedTextComponent",
        "//submodules/Utils/ShelfPack",
    ],
    visibility = [
        "//visibility:public",
    ],
)
