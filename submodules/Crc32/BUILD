
objc_library(
    name = "Crc32",
    enable_modules = True,
    module_name = "Crc32",
    srcs = glob([
        "Sources/**/*.m",
        "Sources/**/*.h",
    ], allow_empty = True),
    hdrs = glob([
        "PublicHeaders/**/*.h",
    ]),
    includes = [
        "PublicHeaders",
    ],
    sdk_frameworks = [
        "Foundation",
    ],
    sdk_dylibs = [
        "libz",
    ],
    visibility = [
        "//visibility:public",
    ],
)
