
objc_library(
    name = "MurMurHash32",
    enable_modules = True,
    module_name = "MurMurHash32",
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
