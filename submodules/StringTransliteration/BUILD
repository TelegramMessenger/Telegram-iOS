
objc_library(
    name = "StringTransliteration",
    enable_modules = True,
    module_name = "StringTransliteration",
    srcs = glob([
        "Source/*.m",
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
