load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

objc_library(
    name = "QOILoader",
    enable_modules = True,
    module_name = "QOILoader",
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
