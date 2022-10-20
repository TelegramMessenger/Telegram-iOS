
objc_library(
    name = "MozjpegBinding",
    module_name = "MozjpegBinding",
    enable_modules = True,
    srcs = glob([
        "Sources/**/*.m",
        "Sources/**/*.h",
    ]),
    hdrs = glob([
        "Public/**/*.h",
    ]),
    includes = [
        "Public",
    ],
    deps = [
        "//third-party/mozjpeg:mozjpeg",
    ],
    visibility = [
        "//visibility:public",
    ]
)
