
load("@rules_cc//cc:cc_library.bzl", "cc_library")

cc_library(
    name = "ogg",
    srcs = glob([
        "Sources/*.c",
        "Sources/*.h",
    ]),
    hdrs = glob([
        "include/ogg/*.h",
    ]),
    includes = [
        "include",
    ],
    copts = [
    ],
    visibility = [
        "//visibility:public",
    ],
)
