
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
        "-Isubmodules/WatchCommon/Host/PublicHeaders/WatchCommon",
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
