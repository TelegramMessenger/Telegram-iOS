
objc_library(
    name = "LegacyImageProcessors",
    enable_modules = True,
    module_name = "LegacyImageProcessors",
    srcs = glob([
        "Sources/**/*.m",
        "Sources/**/*.h",
    ]),
    hdrs = glob([
        "PublicHeaders/**/*.h",
    ]),
    includes = [
        "PublicHeaders",
    ],
    deps = [
        "//submodules/LegacyComponents:LegacyComponents",
    ],
    sdk_frameworks = [
        "Foundation",
        "UIKit",
    ],
    visibility = [
        "//visibility:public",
    ],
)
