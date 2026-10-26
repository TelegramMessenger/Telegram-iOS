
load("@rules_cc//cc:objc_library.bzl", "objc_library")

objc_library(
    name = "StringTransliteration",
    enable_modules = True,
    module_name = "StringTransliteration",
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
