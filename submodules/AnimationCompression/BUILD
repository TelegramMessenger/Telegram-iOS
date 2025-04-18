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
    name = "AnimationCompressionMetalResources",
    srcs = glob([
        "Resources/**/*.metal",
    ]),
    visibility = ["//visibility:public"],
)

plist_fragment(
    name = "AnimationCompressionBundleInfoPlist",
    extension = "plist",
    template =
    """
    <key>CFBundleIdentifier</key>
    <string>org.telegram.AnimationCompression</string>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleName</key>
    <string>AnimationCompression</string>
    """
)

apple_resource_bundle(
    name = "AnimationCompressionBundle",
    infoplists = [
        ":AnimationCompressionBundleInfoPlist",
    ],
    resources = [
        ":AnimationCompressionMetalResources",
    ],
)

swift_library(
    name = "AnimationCompression",
    module_name = "AnimationCompression",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    data = [
        ":AnimationCompressionBundle",
    ],
    deps = [
        ":DctHuffman",
        "//submodules/Components/MetalImageView:MetalImageView",
    ],
    visibility = [
        "//visibility:public",
    ],
)

objc_library(
    name = "DctHuffman",
    enable_modules = True,
    module_name = "DctHuffman",
    srcs = glob([
        "DctHuffman/Sources/**/*.m",
        "DctHuffman/Sources/**/*.mm",
        "DctHuffman/Sources/**/*.h",
    ]),
    copts = [],
    hdrs = glob([
        "DctHuffman/PublicHeaders/**/*.h",
    ]),
    includes = [
        "DctHuffman/PublicHeaders",
    ],
    deps = [
    ],
    sdk_frameworks = [
        "Foundation",
    ],
    visibility = [
        "//visibility:public",
    ],
)
