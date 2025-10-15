
objc_library(
    name = "LibYuvBinding",
    enable_modules = True,
    module_name = "LibYuvBinding",
    srcs = glob([
        "Sources/**/*.m",
        "Sources/**/*.c",
        "Sources/**/*.h",
    ], allow_empty=True),
    hdrs = glob([
        "PublicHeaders/**/*.h",
    ]),
    includes = [
        "PublicHeaders",
    ],
    deps = [
        "//third-party/libyuv",
    ],
    sdk_frameworks = [
        "Foundation",
    ],
    visibility = [
        "//visibility:public",
    ],
)
