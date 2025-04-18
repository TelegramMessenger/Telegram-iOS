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
    name = "CallScreenMetalSources",
    srcs = glob([
        "Metal/**/*.metal",
    ]),
    visibility = ["//visibility:public"],
)

plist_fragment(
    name = "CallScreenMetalSourcesBundleInfoPlist",
    extension = "plist",
    template =
    """
    <key>CFBundleIdentifier</key>
    <string>org.telegram.CallScreenMetalSources</string>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleName</key>
    <string>CallScreen</string>
    """
)

apple_resource_bundle(
    name = "CallScreenMetalSourcesBundle",
    infoplists = [
        ":CallScreenMetalSourcesBundleInfoPlist",
    ],
    resources = [
        ":CallScreenMetalSources",
    ],
)

filegroup(
    name = "Assets",
    srcs = glob(["CallScreenAssets.xcassets/**"]),
    visibility = ["//visibility:public"],
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
        ":CallScreenMetalSourcesBundle",
        ":Assets",
    ],
    deps = [
        "//submodules/Display",
        "//submodules/MetalEngine",
        "//submodules/ComponentFlow",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/TelegramUI/Components/AnimatedTextComponent",
        "//submodules/Components/MultilineTextComponent",
        "//submodules/AppBundle",
        "//submodules/UIKitRuntimeUtils",
        "//submodules/TelegramPresentationData",
    ],
    visibility = [
        "//visibility:public",
    ],
)
