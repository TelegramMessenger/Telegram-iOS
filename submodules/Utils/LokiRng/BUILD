
objc_library(
    name = "LokiRng",
    enable_modules = True,
    module_name = "LokiRng",
    srcs = glob([
        "Sources/**/*.m",
        "Sources/**/*.mm",
        "Sources/**/*.h",
        "Sources/**/*.cpp",
    ]),
    hdrs = glob([
        "PublicHeaders/**/*.h",
    ]),
    includes = [
        "PublicHeaders",
    ],
    sdk_frameworks = [
        "Foundation",
    ],
    visibility = [
        "//visibility:public",
    ],
)
