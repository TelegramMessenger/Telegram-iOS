
load("@rules_cc//cc:objc_library.bzl", "objc_library")

objc_library(
    name = "CallsEmoji",
    enable_modules = True,
    module_name = "CallsEmoji",
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
    ],
    visibility = [
        "//visibility:public",
    ],
)
