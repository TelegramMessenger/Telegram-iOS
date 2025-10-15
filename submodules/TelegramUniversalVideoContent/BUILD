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
    name = "HlsBundleContents",
    srcs = glob([
        "HlsBundle/**",
    ]),
    visibility = ["//visibility:public"],
)

plist_fragment(
    name = "HlsBundleInfoPlist",
    extension = "plist",
    template =
    """
    <key>CFBundleIdentifier</key>
    <string>org.telegram.TelegramUniversalVideoContent</string>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleName</key>
    <string>TelegramUniversalVideoContent</string>
    """
)

apple_resource_bundle(
    name = "HlsBundle",
    infoplists = [
        ":HlsBundleInfoPlist",
    ],
    resources = [
        ":HlsBundleContents",
    ],
)

swift_library(
    name = "TelegramUniversalVideoContent",
    module_name = "TelegramUniversalVideoContent",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    data = [
        ":HlsBundle",
    ],
    deps = [
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/Display:Display",
        "//submodules/Postbox:Postbox",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/MediaPlayer:UniversalMediaPlayer",
        "//submodules/AccountContext:AccountContext",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/PhotoResources:PhotoResources",
        "//submodules/LegacyComponents:LegacyComponents",
        "//submodules/RadialStatusNode:RadialStatusNode",
        "//submodules/AppBundle:AppBundle",
        "//submodules/Utils/RangeSet:RangeSet",
        "//submodules/TelegramVoip",
        "//submodules/ManagedFile",
    ],
    visibility = [
        "//visibility:public",
    ],
)
