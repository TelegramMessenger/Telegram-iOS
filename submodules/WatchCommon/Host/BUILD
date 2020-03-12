
objc_library(
    name = "WatchCommon",
    enable_modules = True,
    module_name = "WatchCommon",
    srcs = glob([
        "Sources/**/*.m",
        "Sources/**/*.h",
    ]),
    hdrs = glob([
        "PublicHeaders/**/*.h",
    ]),
    copts = [
        "-I{}/PublicHeaders/WatchCommon".format(package_name()),
    ],
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
