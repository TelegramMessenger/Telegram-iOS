
objc_library(
    name = "GZip",
    enable_modules = True,
    module_name = "GZip",
    srcs = glob([
        "Sources/**/*.m",
    ]),
    hdrs = glob([
        "Sources/**/*.h",
    ]),
    sdk_dylibs = [
        "libz",
    ],
    visibility = [
        "//visibility:public",
    ],
)
