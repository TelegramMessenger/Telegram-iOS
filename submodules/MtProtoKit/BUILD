
objc_library(
    name = "MtProtoKit",
    enable_modules = True,
    module_name = "MtProtoKit",
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
        "//submodules/EncryptionProvider:EncryptionProvider",
    ],
    sdk_frameworks = [
        "Foundation",
        "Security",
        "SystemConfiguration",
        "CFNetwork",
    ],
    sdk_dylibs = [
        "libz",
    ],
    visibility = [
        "//visibility:public",
    ],
)
