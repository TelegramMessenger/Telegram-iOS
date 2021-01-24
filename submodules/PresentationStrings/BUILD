 
objc_library(
    name = "PresentationStrings",
    enable_modules = True,
    module_name = "PresentationStrings",
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
