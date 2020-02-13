objc_library(
    name = "OpenSSLEncryptionProvider",
    srcs = glob([
        "Sources/**/*.m",
    ]),
    hdrs = glob([
        "Sources/**/*.h",
    ]),
    deps = [
        "//submodules/EncryptionProvider:EncryptionProvider",
        "//submodules/openssl:openssl",
    ],
    visibility = ["//visibility:public"],
)
