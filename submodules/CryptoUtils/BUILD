
load("@rules_cc//cc:objc_library.bzl", "objc_library")

objc_library(
    name = "CryptoUtils",
    enable_modules = True,
    module_name = "CryptoUtils",
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
