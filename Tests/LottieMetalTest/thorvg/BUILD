load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

objc_library(
    name = "thorvg",
    enable_modules = True,
    module_name = "thorvg",
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
        "-I{}/PublicHeaders/thorvg".format(package_name()),
        "-I{}/Sources/common".format(package_name()),
        "-I{}/Sources/loaders/raw".format(package_name()),
        "-I{}/Sources/loaders/tvg".format(package_name()),
        "-I{}/Sources/renderer".format(package_name()),
        "-I{}/Sources/renderer/sw_engine".format(package_name()),
    ],
    hdrs = glob([
        "PublicHeaders/**/*.h",
    ]),
    includes = [
        "PublicHeaders",
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
