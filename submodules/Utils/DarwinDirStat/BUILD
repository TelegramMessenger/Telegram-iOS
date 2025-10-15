
objc_library(
    name = "DarwinDirStat",
    enable_modules = True,
    module_name = "DarwinDirStat",
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
    ],
    visibility = [
        "//visibility:public",
    ],
)
