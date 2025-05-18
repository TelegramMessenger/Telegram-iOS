
objc_library(
    name = "STCMeshView",
    enable_modules = True,
    module_name = "STCMeshView",
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
