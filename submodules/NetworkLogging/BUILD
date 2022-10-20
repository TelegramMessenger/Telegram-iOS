
objc_library(
    name = "NetworkLogging",
    enable_modules = True,
    module_name = "NetworkLogging",
    srcs = glob([
        "Sources/*.m",
    ]),
    hdrs = glob([
        "PublicHeaders/**/*.h",
    ]),
    includes = [
        "PublicHeaders",
    ],
    deps = [
        "//submodules/MtProtoKit:MtProtoKit",
    ],
    sdk_frameworks = [
      "Foundation",
    ],
    visibility = [
        "//visibility:public",
    ],
)
