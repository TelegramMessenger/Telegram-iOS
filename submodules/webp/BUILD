
cc_library(
    name = "webp_lib",
    srcs = [
        "lib/libwebp.a",
    ],
)

objc_library(
    name = "webp",
    module_name = "webp",
    enable_modules = True,
    hdrs = glob([
        "include/**/*.h",
    ]),
    includes = [
        "include",
    ],
    deps = [
        ":webp_lib",
    ],
    visibility = [
        "//visibility:public",
    ]
)
