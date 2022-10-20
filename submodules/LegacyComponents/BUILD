
filegroup(
    name = "LegacyComponentsResources",
    srcs = glob([
        "Resources/LegacyComponentsResources.bundle/**/*",
    ], exclude = ["Resources/LegacyComponentsResources.bundle/**/.*"]),
    visibility = ["//visibility:public"],
)

filegroup(
    name = "LegacyComponentsAssets",
    srcs = glob(["LegacyImages.xcassets/**"]),
    visibility = ["//visibility:public"],
)


objc_library(
    name = "LegacyComponents",
    enable_modules = True,
    module_name = "LegacyComponents",
    srcs = glob([
        "Sources/*.m",
        "Sources/*.mm",
        "Sources/*.c",
        "Sources/*.cpp",
        "Sources/*.h",
    ]),
    hdrs = glob([
        "PublicHeaders/**/*.h",
    ]),
    copts = [
        "-I{}/PublicHeaders/LegacyComponents".format(package_name()),
        #"-Werror",
    ],
    includes = [
        "PublicHeaders",
    ],
    deps = [
        "//submodules/SSignalKit/SSignalKit:SSignalKit",
        "//submodules/AppBundle:AppBundle",
    ],
    sdk_frameworks = [
        "Foundation",
        "UIKIt",
        "QuickLook",
        "CoreMotion",
    ],
    weak_sdk_frameworks = [
        "Vision",
        "PhotosUI",
    ],
    visibility = [
        "//visibility:public",
    ],
)
