
objc_library(
    name = "Stripe",
    enable_modules = True,
    module_name = "Stripe",
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
    copts = [
        "-Isubmodules/Stripe/PublicHeaders/Stripe",
    ],
    sdk_frameworks = [
        "Foundation",
        "UIKit",
        "PassKit",
    ],
    visibility = [
        "//visibility:public",
    ],
)
