load("//build-system/bazel-utils:unique_directories.bzl", "unique_directories")

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
        "-I{}/{}".format(package_name(), directory) for directory in unique_directories(private_headers)
    ] + [
        "-I{}/lottie-ios/Classes/PublicHeaders/Lottie".format(package_name()),
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
