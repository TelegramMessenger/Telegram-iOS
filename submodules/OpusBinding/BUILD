
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
        "-Isubmodules/OpusBinding/Sources",
        "-Isubmodules/OpusBinding/Sources/opusfile",
        "-Isubmodules/OpusBinding/PublicHeaders/OpusBinding",
    ],
    deps = [
        "//submodules/Opus:opus",
    ],
    sdk_frameworks = [
        "Foundation",
    ],
    visibility = [
        "//visibility:public",
    ],
)
