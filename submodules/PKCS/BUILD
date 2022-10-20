
objc_library(
    name = "PKCS",
    enable_modules = True,
    module_name = "PKCS",
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
    copts = [
        "-DTELEGRAM_USE_BORINGSSL=1",
    ],
    deps = [
        "//third-party/boringssl:crypto",
    ],
    sdk_frameworks = [
        "Foundation",
    ],
    visibility = [
        "//visibility:public",
    ],
)
