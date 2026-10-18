load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library", "swift_test")
load(
    "@build_bazel_rules_apple//apple:resources.bzl",
    "apple_resource_bundle",
    "apple_resource_group",
)
load("//build-system/bazel-utils:plist_fragment.bzl",
    "plist_fragment",
)

filegroup(
    name = "StoryPeerListMetalResources",
    srcs = glob([
        "MetalResources/**/*.*",
    ]),
    visibility = ["//visibility:public"],
)

plist_fragment(
    name = "StoryPeerListBundleInfoPlist",
    extension = "plist",
    template =
    """
    <key>CFBundleIdentifier</key>
    <string>org.telegram.StoryPeerList</string>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleName</key>
    <string>StoryPeerList</string>
    """
)

apple_resource_bundle(
    name = "StoryPeerListBundle",
    infoplists = [
        ":StoryPeerListBundleInfoPlist",
    ],
    resources = [
        ":StoryPeerListMetalResources",
    ],
)

swift_library(
    name = "StoryPeerListComponent",
    module_name = "StoryPeerListComponent",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    data = [
        ":StoryPeerListBundle",
    ],
    deps = [
        "//submodules/Display",
        "//submodules/MetalEngine",
        "//submodules/ComponentFlow",
        "//submodules/AppBundle",
        "//submodules/Components/BundleIconComponent",
        "//submodules/AccountContext",
        "//submodules/TelegramCore",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/TelegramPresentationData",
        "//submodules/AvatarNode",
        "//submodules/ContextUI",
        "//submodules/TelegramUI/Components/Stories/StoryContainerScreen",
        "//submodules/Components/MultilineTextComponent",
        "//submodules/TelegramUI/Components/EmojiStatusComponent",
        "//submodules/Components/HierarchyTrackingLayer",
        "//submodules/TelegramUI/Components/ChatListTitleView",
        "//submodules/TelegramUI/Components/Utils/AnimatableProperty",
    ],
    visibility = [
        "//visibility:public",
    ],
)

# Host (macOS) test of the collapsed header's title layout: only that file is compiled, it needs nothing but CoreGraphics.
# Run with `./build-input/bazel-9.2.0-darwin-arm64 test //submodules/TelegramUI/Components/Stories/StoryPeerListComponent:StoryPeerListTitleLayoutTests`.
swift_test(
    name = "StoryPeerListTitleLayoutTests",
    srcs = [
        "Sources/StoryPeerListTitleLayout.swift",
        "Tests/StoryPeerListTitleLayoutTests.swift",
    ],
    copts = [
        "-warnings-as-errors",
    ],
)

# Host (macOS) test of the expanded row's spacing when its avatars do not all fit, built the same way.
# Run with `./build-input/bazel-9.2.0-darwin-arm64 test //submodules/TelegramUI/Components/Stories/StoryPeerListComponent:StoryPeerListRowLayoutTests`.
swift_test(
    name = "StoryPeerListRowLayoutTests",
    srcs = [
        "Sources/StoryPeerListRowLayout.swift",
        "Tests/StoryPeerListRowLayoutTests.swift",
    ],
    copts = [
        "-warnings-as-errors",
    ],
)
