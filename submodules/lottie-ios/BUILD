load("//build-system:unique_directories.bzl", "unique_directories")

private_headers = glob([
    "lottie-ios/**/*.h",
], exclude = [
    "lottie-ios/Classes/PublicHeaders/**/*.h",
])

objc_library(
    name = "Lottie",
    enable_modules = True,
    module_name = "Lottie",
    srcs = glob([
        "lottie-ios/**/*.m",
    ]) + private_headers,
    copts = [
        "-Isubmodules/lottie-ios/{}".format(directory) for directory in unique_directories(private_headers)
    ] + [
        "-Isubmodules/lottie-ios/lottie-ios/Classes/PublicHeaders/Lottie",
    ],
    hdrs = glob([
        "lottie-ios/Classes/PublicHeaders/**/*.h",
    ]),
    includes = [
        "lottie-ios/Classes/PublicHeaders",
    ],
    sdk_frameworks = [
        "Foundation",
        "UIKit",
    ],
    visibility = [
        "//visibility:public",
    ],
)
