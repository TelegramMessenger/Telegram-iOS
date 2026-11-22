load("@rules_cc//cc:objc_library.bzl", "objc_library")
load("@build_bazel_rules_apple//apple:resources.bzl", "apple_resource_bundle")
load("//build-system/bazel-utils:plist_fragment.bzl", "plist_fragment")

plist_fragment(
    name = "CompanionResourcesInfo",
    extension = "plist",
    template = "<key>CFBundleIdentifier</key><string>org.telegram.CompanionResources</string><key>CFBundleName</key><string>CompanionResources</string>",
)
apple_resource_bundle(
    name = "CompanionResources",
    infoplists = [":CompanionResourcesInfo"],
    resources = glob(["Resources/*"]),
)
objc_library(
    name = "CompanionRenderer",
    module_name = "CompanionRenderer",
    enable_modules = True,
    srcs = glob(["Sources/*.mm", "Core/*.cpp", "Core/*.hpp", "ThirdParty/opensubdiv/*/*.cpp", "ThirdParty/opensubdiv/**/*.h", "ThirdParty/cgltf/*.h"]),
    hdrs = ["Public/CompanionRenderer.h"],
    includes = ["Public", "Core", "ThirdParty/cgltf"],
    copts = ["-std=c++17", "-fexceptions"],
    sdk_frameworks = ["Foundation", "Metal", "QuartzCore", "ImageIO", "CoreGraphics"],
    sdk_dylibs = ["c++"],
    data = [":CompanionResources"],
    visibility = ["//visibility:public"],
)
