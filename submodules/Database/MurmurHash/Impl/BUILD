
objc_library(
    name = "MurMurHashObjC",
    enable_modules = True,
    module_name = "MurMurHashObjC",
    srcs = glob([
        "Sources/**/*.m",
        "Sources/**/*.h",
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
