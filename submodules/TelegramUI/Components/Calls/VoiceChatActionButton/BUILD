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
    name = "VoiceChatActionButtonMetalSources",
    srcs = glob([
        "Metal/**/*.metal",
    ]),
    visibility = ["//visibility:public"],
)

plist_fragment(
    name = "VoiceChatActionButtonMetalSourcesBundleInfoPlist",
    extension = "plist",
    template =
    """
    <key>CFBundleIdentifier</key>
    <string>org.telegram.VoiceChatActionButtonMetalSources</string>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleName</key>
    <string>VoiceChatActionButton</string>
    """
)

apple_resource_bundle(
    name = "VoiceChatActionButtonMetalSourcesBundle",
    infoplists = [
        ":VoiceChatActionButtonMetalSourcesBundleInfoPlist",
    ],
    resources = [
        ":VoiceChatActionButtonMetalSources",
    ],
)

filegroup(
    name = "Assets",
    srcs = glob(["VoiceChatActionButtonAssets.xcassets/**"]),
    visibility = ["//visibility:public"],
)

swift_library(
    name = "VoiceChatActionButton",
    module_name = "VoiceChatActionButton",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    data = [
        ":VoiceChatActionButtonMetalSourcesBundle",
        ":Assets",
    ],
    deps = [
        "//submodules/Display",
        "//submodules/MetalEngine",
        "//submodules/ComponentFlow",
        "//submodules/UIKitRuntimeUtils",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/AppBundle",
        "//submodules/ManagedAnimationNode",
        "//submodules/AnimationUI",
        "//submodules/TelegramUI/Components/Calls/CallScreen",
    ],
    visibility = [
        "//visibility:public",
    ],
)
