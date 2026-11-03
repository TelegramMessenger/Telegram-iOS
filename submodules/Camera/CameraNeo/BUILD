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
    name = "CameraNeoMetalResources",
    srcs = glob([
        "MetalResources/**/*.*",
    ]),
    visibility = ["//visibility:public"],
)

plist_fragment(
    name = "CameraNeoBundleInfoPlist",
    extension = "plist",
    template =
    """
    <key>CFBundleIdentifier</key>
    <string>org.telegram.CameraNeo</string>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleName</key>
    <string>CameraNeo</string>
    """,
)

apple_resource_bundle(
    name = "CameraNeoBundle",
    infoplists = [
        ":CameraNeoBundleInfoPlist",
    ],
    resources = [
        ":CameraNeoMetalResources",
    ],
)

swift_library(
    name = "CameraNeo",
    module_name = "CameraNeo",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    data = [
        ":CameraNeoBundle",
    ],
    deps = [
        "//submodules/AppBundle",
        "//submodules/Camera",
        "//submodules/GZip",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/Utils/DeviceModel",
        "//submodules/LottieBinding:LottieBinding",
        "//submodules/LottieSettings:LottieSettings",
    ],
    visibility = [
        "//visibility:public",
    ],
)
