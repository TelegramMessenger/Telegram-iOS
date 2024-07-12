
objc_library(
    name = "TonutilsProxyBridge",
    enable_modules = True,
    module_name = "TonutilsProxyBridge",
    srcs = glob([
        "Sources/**/*.h",
        "Sources/**/*.m",
    ]),
    hdrs = glob([
        "PublicHeaders/**/*.h",
    ]),
    includes = [
      "PublicHeaders",
    ],
    deps = [
        "//third-party/tonutilsproxy",
    ],
    visibility = [
        "//visibility:public",
    ],
)
