
objc_library(
    name = "AppBundle",
    module_name = "AppBundle",
    enable_modules = True,
    srcs = glob([
        "Sources/**/*.m",
        "Sources/**/*.h",
    ], allow_empty=True),
    hdrs = glob([
        "PublicHeaders/**/*.h",
    ]),
    includes = [
       "PublicHeaders", 
    ],
    sdk_frameworks = [
        "Foundation",
        "UIKit",
    ],
    visibility = [
        "//visibility:public",
    ],
)
