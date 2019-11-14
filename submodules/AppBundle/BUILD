
objc_library(
    name = "AppBundle",
    enable_modules = True,
    module_name = "AppBundle",
    srcs = glob([
        "Source/AppBundle/*.m",
    ]),
    hdrs = glob([
        "Source/AppBundle/*.h",
    ]),
    includes = [
      "Source",
    ],
    sdk_frameworks = [
      "Foundation",
      "UIKit",
    ],
    visibility = [
        "//visibility:public",
    ],
)
