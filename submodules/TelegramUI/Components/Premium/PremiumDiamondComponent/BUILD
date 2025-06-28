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
    name = "PremiumDiamondComponentMetalResources",
    srcs = glob([
        "MetalResources/**/*.*",
    ]),
    visibility = ["//visibility:public"],
)

plist_fragment(
    name = "PremiumDiamondComponentBundleInfoPlist",
    extension = "plist",
    template =
    """
    <key>CFBundleIdentifier</key>
    <string>org.telegram.PremiumDiamondComponent</string>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleName</key>
    <string>StoryPeerList</string>
    """
)

apple_resource_bundle(
    name = "PremiumDiamondComponentBundle",
    infoplists = [
        ":PremiumDiamondComponentBundleInfoPlist",
    ],
    resources = [
        ":PremiumDiamondComponentMetalResources",
    ],
)

swift_library(
    name = "PremiumDiamondComponent",
    module_name = "PremiumDiamondComponent",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    data = [
        ":PremiumDiamondComponentBundle",
    ],
    deps = [
        "//submodules/AsyncDisplayKit",
        "//submodules/Display",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/MetalEngine",
        "//submodules/ComponentFlow",
        "//submodules/AccountContext",
        "//submodules/AppBundle",
        "//submodules/GZip",
        "//submodules/LegacyComponents",
        "//submodules/TelegramPresentationData",
        "//submodules/Components/MultilineTextComponent:MultilineTextComponent",
        "//submodules/TelegramUI/Components/Premium/PremiumStarComponent",
        "//submodules/TelegramUI/Components/Utils/AnimatableProperty",
    ],
    visibility = [
        "//visibility:public",
    ],
)
