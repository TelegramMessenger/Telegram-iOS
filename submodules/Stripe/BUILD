
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
        "-I{}/PublicHeaders/Stripe".format(package_name()),
    ],
    sdk_frameworks = [
        "Foundation",
        "UIKit",
        "AddressBook",
    ],
    weak_sdk_frameworks = [
        "PassKit",
    ],
    visibility = [
        "//visibility:public",
    ],
)
