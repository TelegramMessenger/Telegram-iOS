
objc_library(
    name = "OpusBinding",
    enable_modules = True,
    module_name = "OpusBinding",
    srcs = glob([
        "Sources/**/*.m",
        "Sources/**/*.c",
        "Sources/**/*.h",
    ]),
    hdrs = glob([
        "PublicHeaders/**/*.h",
    ]),
    includes = [
        "PublicHeaders",
    ],
    copts = [
        "-I{}/Sources".format(package_name()),
        "-I{}/Sources/opusfile".format(package_name()),
        "-I{}/PublicHeaders/OpusBinding".format(package_name()),
    ],
    deps = [
        "//third-party/opus:opus",
    ],
    sdk_frameworks = [
        "Foundation",
    ],
    visibility = [
        "//visibility:public",
    ],
)
