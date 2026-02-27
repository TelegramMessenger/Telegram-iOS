
objc_library(
    name = "MozjpegBinding",
    module_name = "MozjpegBinding",
    enable_modules = True,
    srcs = glob([
        "Sources/**/*.m",
        "Sources/**/*.mm",
        "Sources/**/*.h",
    ], allow_empty=True),
    hdrs = glob([
        "Public/**/*.h",
    ]),
    includes = [
        "Public",
    ],
    deps = [
        "//third-party/mozjpeg:mozjpeg",
        #"//third-party/libjxl:jxl",
    ],
    visibility = [
        "//visibility:public",
    ]
)
