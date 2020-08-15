
cc_library(
    name = "opus_lib",
    srcs = [
        "Sources/opus/lib/libopus.a",
    ],
)

objc_library(
    name = "opus",
    module_name = "opus",
    enable_modules = True,
    hdrs = glob([
        "Public/**/*.h",
    ]),
    includes = [
        "Public",
        "Public/opus",
    ],
    deps = [
        ":opus_lib",
    ],
    visibility = [
        "//visibility:public",
    ]
)
