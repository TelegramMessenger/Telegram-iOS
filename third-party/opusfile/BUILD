 
objc_library(
    name = "opusfile",
    enable_modules = True,
    module_name = "opusfile",
    srcs = glob([
        "Sources/*.c",
        "Sources/*.h",
    ]),
    hdrs = glob([
        "include/opusfile/*.h",
    ]),
    includes = [
        "include",
    ],
    deps = [
        "//third-party/ogg:ogg",
        "//third-party/opus:opus",
    ],
    visibility = [
        "//visibility:public",
    ],
)
