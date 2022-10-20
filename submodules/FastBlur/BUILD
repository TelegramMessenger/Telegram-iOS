
objc_library(
    name = "FastBlur",
    enable_modules = True,
    module_name = "FastBlur",
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
      "UIKit",
      "Accelerate",
    ],
    visibility = [
        "//visibility:public",
    ],
)
