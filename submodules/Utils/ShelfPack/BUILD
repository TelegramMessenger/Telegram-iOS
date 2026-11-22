
load("@rules_cc//cc:objc_library.bzl", "objc_library")

objc_library(
    name = "ShelfPack",
    enable_modules = True,
    module_name = "ShelfPack",
    srcs = glob([
        "Sources/**/*.m",
        "Sources/**/*.mm",
        "Sources/**/*.h",
        "Sources/**/*.hpp",
        "Sources/**/*.cpp",
    ], allow_empty=True),
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
