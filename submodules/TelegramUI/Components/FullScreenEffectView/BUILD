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
    name = "FullScreenEffectViewMetalResources",
    srcs = glob([
        "MetalResources/**/*.*",
    ]),
    visibility = ["//visibility:public"],
)

plist_fragment(
    name = "FullScreenEffectViewBundleInfoPlist",
    extension = "plist",
    template =
    """
    <key>CFBundleIdentifier</key>
    <string>org.telegram.FullScreenEffectView</string>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleName</key>
    <string>FullScreenEffectView</string>
    """
)

apple_resource_bundle(
    name = "FullScreenEffectViewBundle",
    infoplists = [
        ":FullScreenEffectViewBundleInfoPlist",
    ],
    resources = [
        ":FullScreenEffectViewMetalResources",
    ],
)

filegroup(
    name = "FullScreenEffectViewResources",
    srcs = glob([
        "Resources/**/*",
    ], allow_empty=True, exclude = ["Resources/**/.*"]),
    visibility = ["//visibility:public"],
)

swift_library(
    name = "FullScreenEffectView",
    module_name = "FullScreenEffectView",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/ComponentFlow",
    ],
    data = [
        ":FullScreenEffectViewBundle",
    ],
    visibility = [
        "//visibility:public",
    ],
)
