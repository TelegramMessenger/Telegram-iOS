
load("@rules_cc//cc:cc_library.bzl", "cc_library")

cc_library(
    name = "opusfile",
    srcs = glob([
        "Sources/*.c",
        "Sources/*.h",
    ]),
    hdrs = glob([
        "include/opusfile/*.h",
    ]),
    includes = [
        "include",
    ],
    deps = [
        "//third-party/ogg:ogg",
        "//third-party/opus:opus",
    ],
    visibility = [
        "//visibility:public",
    ],
)
