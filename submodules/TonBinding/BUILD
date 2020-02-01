load(
    "@rules_apple_extras//apple:objc_library.bzl",
    "objc_library",
)

objc_library(
    name = "TonBinding",
    srcs = glob([
        "Sources/**/*.m",
        "Sources/**/*.mm",
    ]),
    hdrs = glob([
        "Sources/**/*.h",
    ]),
    deps = [
        "//submodules/SSignalKit/SSignalKit:SSignalKit",
        "//submodules/openssl:openssl",
        "//submodules/ton:ton",
    ],
    visibility = [
        "//visibility:public",
    ],
)
