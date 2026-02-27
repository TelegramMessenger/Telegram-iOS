
objc_library(
    name = "WebPBinding",
    enable_modules = True,
    module_name = "WebPBinding",
    srcs = glob([
        "Sources/**/*.m",
    ]),
    hdrs = glob([
        "PublicHeaders/**/*.h",
    ]),
    includes = [
        "PublicHeaders",
    ],
    deps = [
        "//third-party/webp:webp",
    ],
    sdk_frameworks = [
        "Foundation",
        "UIKit",
    ],
    visibility = [
        "//visibility:public",
    ],
)
