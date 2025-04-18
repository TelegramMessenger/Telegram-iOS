
objc_library(
    name = "OpenSSLEncryptionProvider",
    enable_modules = True,
    module_name = "OpenSSLEncryptionProvider",
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
        "-Werror",
    ],
    deps = [
        "//submodules/EncryptionProvider:EncryptionProvider",
        "//third-party/boringssl:crypto",
    ],
    sdk_frameworks = [
        "Foundation",
    ],
    visibility = [
        "//visibility:public",
    ],
)
