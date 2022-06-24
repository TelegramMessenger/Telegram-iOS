
objc_library(
    name = "DCT",
    enable_modules = True,
    module_name = "DCT",
    srcs = glob([
        "Sources/**/*.m",
        "Sources/**/*.h",
    ]),
    hdrs = glob([
        "PublicHeaders/**/*.h",
    ]),
    includes = [
        "PublicHeaders",
    ],
    sdk_frameworks = [
        "Foundation",
        "Accelerate",
    ],
    visibility = [
        "//visibility:public",
    ],
)
