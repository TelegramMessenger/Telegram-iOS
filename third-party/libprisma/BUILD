load(
    "@build_bazel_rules_apple//apple:resources.bzl",
    "apple_resource_bundle",
    "apple_resource_group",
)
load("//build-system/bazel-utils:plist_fragment.bzl",
    "plist_fragment",
)

filegroup(
    name = "LibprismaResources",
    srcs = glob([
        "Resources/**/*.dat",
    ]),
    visibility = ["//visibility:public"],
)

plist_fragment(
    name = "LibprismaInfoPlist",
    extension = "plist",
    template =
    """
    <key>CFBundleIdentifier</key>
    <string>org.telegram.Libprisma</string>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleName</key>
    <string>Libprisma</string>
    """
)

apple_resource_bundle(
    name = "LibprismaBundle",
    infoplists = [
        ":LibprismaInfoPlist",
    ],
    resources = [
        ":LibprismaResources",
    ],
)
 
objc_library(
    name = "libprisma",
    enable_modules = True,
    module_name = "libprisma",
    srcs = glob([
        "Sources/**/*.c",
        "Sources/**/*.cpp",
        "Sources/**/*.m",
        "Sources/**/*.mm",
        "Sources/**/*.h",
        "Sources/**/*.hpp",
    ], allow_empty=True),
    hdrs = glob([
        "include/libprisma/*.h",
    ]),
    includes = [
        "include",
    ],
    data = [
        ":LibprismaBundle",
    ],
    copts = [
        "-Ithird-party/libprisma/include/libprisma",
    ],
    deps = [
        "//third-party/boost_regex",
    ],
    sdk_frameworks = [
        "Foundation",
        "UIKit",
    ],
    visibility = [
        "//visibility:public",
    ],
)
