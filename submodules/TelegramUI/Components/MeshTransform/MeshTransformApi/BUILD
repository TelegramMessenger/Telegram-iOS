
load("@rules_cc//cc:objc_library.bzl", "objc_library")

objc_library(
    name = "MeshTransformApi",
    enable_modules = True,
    module_name = "MeshTransformApi",
    srcs = glob([
        "Sources/*.m",
    ]),
    hdrs = glob([
        "PublicHeaders/**/*.h",
    ]),
    includes = [
        "PublicHeaders",
    ],
    sdk_frameworks = [
        "Foundation",
        "UIKit",
    ],
    visibility = [
        "//visibility:public",
    ],
)
