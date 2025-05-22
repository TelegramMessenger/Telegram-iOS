load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

objc_library(
    name = "SoftwareLottieRenderer",
    enable_modules = True,
    module_name = "SoftwareLottieRenderer",
    srcs = glob([
        "Sources/**/*.m",
        "Sources/**/*.mm",
        "Sources/**/*.h",
        "Sources/**/*.c",
        "Sources/**/*.cpp",
        "Sources/**/*.hpp",
    ]),
    copts = [
        "-Werror",
        "-I{}/Sources".format(package_name()),
    ],
    cxxopts = [
        "-Werror",
        "-std=c++17",
        "-I{}/Sources".format(package_name()),
    ],
    hdrs = glob([
        "PublicHeaders/**/*.h",
    ]),
    includes = [
        "PublicHeaders",
    ],
    deps = [
        "//submodules/LottieCpp",
        "//Tests/LottieMetalTest/thorvg",
        "//Tests/LottieMetalTest/skia",
        "//Tests/LottieMetalTest/skia:libskia"
    ],
    sdk_frameworks = [
        "Foundation",
    ],
    visibility = [
        "//visibility:public",
    ],
)
