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
    name = "LottieMeshSwiftMetalResources",
    srcs = glob([
        "Resources/**/*.metal",
    ]),
    visibility = ["//visibility:public"],
)

plist_fragment(
    name = "LottieMeshSwiftBundleInfoPlist",
    extension = "plist",
    template =
    """
    <key>CFBundleIdentifier</key>
    <string>org.telegram.LottieMeshSwift</string>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleName</key>
    <string>LottieMeshSwift</string>
    """
)

apple_resource_bundle(
    name = "LottieMeshSwiftBundle",
    infoplists = [
        ":LottieMeshSwiftBundleInfoPlist",
    ],
    resources = [
        ":LottieMeshSwiftMetalResources",
    ],
)

config_setting(
    name = "debug_build",
    values = {
        "compilation_mode": "dbg",
    },
)

optimization_flags = select({
    ":debug_build": [
        "-O2",
    ],
    "//conditions:default": [],
})

swift_optimization_flags = select({
    ":debug_build": [
        #"-O",
    ],
    "//conditions:default": [],
})

swift_library(
    name = "LottieMeshSwift",
    module_name = "LottieMeshSwift",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ] + swift_optimization_flags,
    data = [
        ":LottieMeshSwiftBundle",
    ],
    deps = [
        ":LottieMeshBinding",
        "//submodules/Postbox:Postbox",
        "//submodules/ManagedFile:ManagedFile",
    ],
    visibility = [
        "//visibility:public",
    ],
)

objc_library(
    name = "LottieMeshBinding",
    enable_modules = True,
    module_name = "LottieMeshBinding",
    srcs = glob([
        "LottieMeshBinding/Sources/**/*.m",
        "LottieMeshBinding/Sources/**/*.mm",
        "LottieMeshBinding/Sources/**/*.h",
    ]),
    copts = optimization_flags,
    hdrs = glob([
        "LottieMeshBinding/PublicHeaders/**/*.h",
    ]),
    includes = [
        "LottieMeshBinding/PublicHeaders",
    ],
    deps = [
        ":LottieMesh",
    ],
    sdk_frameworks = [
        "Foundation",
    ],
    visibility = [
        "//visibility:public",
    ],
)

cc_library(
    name = "LottieMesh",
    srcs = glob([
        "LottieMesh/Sources/**/*.cpp",
        "LottieMesh/Sources/**/*.h",
        "LottieMesh/Sources/**/*.hpp",
    ]),
    copts = [
        "-Isubmodules/LottieMeshSwift/libtess2/Include",
    ] + optimization_flags,
    hdrs = glob([
        "LottieMesh/PublicHeaders/**/*.h",
        "LottieMesh/PublicHeaders/**/*.hpp",
    ]),
    includes = [
        "LottieMesh/PublicHeaders",
    ],
    deps = [
        ":libtess2",
    ],
    visibility = [
        "//visibility:public",
    ],
)

cc_library(
    name = "libtess2",
    srcs = glob([
        "libtess2/Sources/**/*.c",
        "libtess2/Sources/**/*.h",
        "libtess2/Include/**/*.h",
    ]),
    copts = [
        "-Isubmodules/LottieMeshSwift/libtess2/Include",
    ] + optimization_flags,
    hdrs = glob([
        "libtess2/Include/**/*.h",
    ]),
    deps = [
    ],
    visibility = [
        "//visibility:public",
    ],
)
