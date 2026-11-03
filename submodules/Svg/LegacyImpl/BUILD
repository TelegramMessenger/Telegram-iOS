
load("@rules_cc//cc:objc_library.bzl", "objc_library")

objc_library(
    name = "LegacyImpl",
    enable_modules = True,
    module_name = "LegacyImpl",
    srcs = glob([
        "Sources/**/*.m",
        "Sources/**/*.c",
        "Sources/**/*.h",
    ]),
    hdrs = glob([
        "PublicHeaders/**/*.h",
    ]),
    includes = [
        "PublicHeaders",
    ],
    sdk_frameworks = [
        "Foundation",
    ],
    visibility = [
        "//visibility:public",
    ],
)
