
load("@rules_cc//cc:objc_library.bzl", "objc_library")

objc_library(
    name = "OverlayStatusControllerImpl",
    module_name = "OverlayStatusControllerImpl",
    srcs = glob([
        "Sources/**/*.m",
    ]),
    hdrs = glob([
        "Sources/**/*.h",
    ]),
    includes = [
        "Sources",
    ],
    copts = [
        "-Werror",
    ],
    visibility = [
        "//visibility:public",
    ],
)
