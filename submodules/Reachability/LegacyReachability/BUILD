
objc_library(
    name = "LegacyReachability",
    enable_modules = True,
    module_name = "LegacyReachability",
    srcs = glob([
        "Sources/*.m",
    ]),
    hdrs = glob([
        "PublicHeaders/**/*.h",
    ]),
    includes = [
        "PublicHeaders",
    ],
    sdk_frameworks = [
      "Foundation",
      "SystemConfiguration",
    ],
    visibility = [
        "//visibility:public",
    ],
)
