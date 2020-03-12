
objc_library(
    name = "Reachability",
    enable_modules = True,
    module_name = "Reachability",
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
