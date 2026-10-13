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
    name = "MetalSources",
    srcs = glob([
        "Sources/**/*.metal",
    ]),
    visibility = ["//visibility:public"],
)

plist_fragment(
    name = "MetalEngineMetalSourcesBundleInfoPlist",
    extension = "plist",
    template =
    """
    <key>CFBundleIdentifier</key>
    <string>org.telegram.MetalEngineMetalSources</string>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleName</key>
    <string>MetalEngine</string>
    """
)

apple_resource_bundle(
    name = "MetalEngineMetalSourcesBundle",
    infoplists = [
        ":MetalEngineMetalSourcesBundleInfoPlist",
    ],
    resources = [
        ":MetalSources",
    ],
)

swift_library(
    name = "MetalEngine",
    module_name = "MetalEngine",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    data = [
        ":MetalEngineMetalSourcesBundle",
    ],
    deps = [
        "//submodules/Display",
        "//submodules/Utils/ShelfPack",
    ],
    visibility = [
        "//visibility:public",
    ],
)

# Host (macOS) test of the pipeline cache, run on the Mac's GPU with `bazel test`, like the tgcalls cc_tests:
# the simulator has no binary archives (serializing one fails an assertion there), so an ios_unit_test cannot reach
# this code. Only the cache's own sources are compiled; they need nothing but Foundation and Metal. Zombies make a
# use of a freed object fail deterministically (see MetalBinaryArchiveSerialization.swift).
swift_test(
    name = "MetalPipelineCacheTests",
    srcs = [
        "Sources/MetalBinaryArchiveSerialization.swift",
        "Sources/MetalPipelineCache.swift",
        "Tests/MetalPipelineCacheTests.swift",
    ],
    copts = [
        "-warnings-as-errors",
    ],
    env = {
        "NSZombieEnabled": "YES",
    },
)
