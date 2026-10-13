load("@rules_cc//cc:objc_library.bzl", "objc_library")

objc_library(
    name = "CpuProfiler",
    enable_modules = True,
    module_name = "CpuProfiler",
    srcs = glob([
        "Sources/*.mm",
    ]),
    hdrs = glob([
        "PublicHeaders/**/*.h",
    ]),
    includes = [
        "PublicHeaders",
    ],
    copts = [
        "-std=c++17",
    ],
    sdk_frameworks = [
        "Foundation",
    ],
    visibility = [
        "//visibility:public",
    ],
)
