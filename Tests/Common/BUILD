
load("@rules_cc//cc:objc_library.bzl", "objc_library")

filegroup(
    name = "LaunchScreen",
    srcs = [
        "Base.lproj/LaunchScreen.xib",
    ],
    visibility = ["//visibility:public"],
)

objc_library(
    name = "Main",
    srcs = [
        "Main/main.m"
    ],
    visibility = ["//visibility:public"],
)
