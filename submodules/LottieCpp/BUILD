load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

objc_library(
    name = "LottieCpp",
    enable_modules = True,
    module_name = "LottieCpp",
    srcs = glob([
        "lottiecpp/Sources/**/*.m",
        "lottiecpp/Sources/**/*.mm",
        "lottiecpp/Sources/**/*.h",
        "lottiecpp/Sources/**/*.c",
        "lottiecpp/Sources/**/*.cpp",
        "lottiecpp/Sources/**/*.hpp",
        "lottiecpp/PlatformSpecific/Darwin/Sources/**/*.m",
        "lottiecpp/PlatformSpecific/Darwin/Sources/**/*.mm",
        "lottiecpp/PlatformSpecific/Darwin/Sources/**/*.h",
        "lottiecpp/PlatformSpecific/Darwin/Sources/**/*.c",
        "lottiecpp/PlatformSpecific/Darwin/Sources/**/*.cpp",
        "lottiecpp/PlatformSpecific/Darwin/Sources/**/*.hpp",
    ], allow_empty=True),
    copts = [
        "-Werror",
        "-I{}/lottiecpp/Sources".format(package_name()),
    ],
    cxxopts = [
        "-std=c++17",
    ],
    hdrs = glob([
        "lottiecpp/PublicHeaders/**/*.h",
        "lottiecpp/PublicHeaders/**/*.hpp",
    ]),
    includes = [
        "lottiecpp/PublicHeaders",
    ],
    deps = [
    ],
    sdk_frameworks = [
        "Foundation",
    ],
    visibility = [
        "//visibility:public",
    ],
)

cc_library(
    name = "LottieCppBinding",
    srcs = [],
    hdrs = glob([
        "lottiecpp/PublicHeaders/**/*.h",
        "lottiecpp/PlatformSpecific/Darwin/PublicHeaders/**/*.h",
    ], allow_empty=True),
    includes = [
        "PublicHeaders",
    ],
    copts = [],
    cxxopts = [
        "-std=c++17",
    ],
    visibility = ["//visibility:public"],
    linkstatic = 1,
)
