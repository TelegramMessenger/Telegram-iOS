
objc_library(
    name = "ImageDCT",
    enable_modules = True,
    module_name = "ImageDCT",
    srcs = glob([
        "Sources/**/*.m",
        "Sources/**/*.mm",
        "Sources/**/*.c",
        "Sources/**/*.cpp",
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
