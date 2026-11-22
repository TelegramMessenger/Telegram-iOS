
load("@rules_cc//cc:objc_library.bzl", "objc_library")

objc_library(
    name = "SSignalKit",
    enable_modules = True,
    module_name = "SSignalKit",
    srcs = glob([
        "Source/SSignalKit/*.m",
    ]),
    copts = [
        "-Werror",
    ],
    hdrs = glob([
        "Source/SSignalKit/*.h",
    ]),
    includes = [
      "Source",
    ],
    deps = [
    ],
    sdk_frameworks = [
      "Foundation",
    ],
    visibility = [
        "//visibility:public",
    ],
)
