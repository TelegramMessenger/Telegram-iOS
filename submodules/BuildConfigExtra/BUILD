
objc_library(
    name = "BuildConfigExtra",
    enable_modules = True,
    module_name = "BuildConfigExtra",
    srcs = glob([
        "Sources/**/*.m",
        "Sources/**/*.h",
    ]),
    copts = [
        "-Werror",
    ],
    hdrs = glob([
        "PublicHeaders/**/*.h",
    ]),
    includes = [
        "PublicHeaders",
    ],
    deps = [
        "//submodules/PKCS:PKCS",
    ],
    sdk_frameworks = [
        "Foundation",
    ],
    visibility = [
        "//visibility:public",
    ],
)
