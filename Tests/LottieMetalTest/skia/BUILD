load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load("@build_bazel_rules_apple//apple:apple.bzl",
    "apple_dynamic_framework_import",
)


apple_dynamic_framework_import(
    name = "libskia",
    framework_imports = glob([
        "libskia.framework/**"
    ]),
    visibility = ["//visibility:public"],
)

objc_library(
    name = "skia",
    enable_modules = True,
    module_name = "skia",
    srcs = glob([
    ]),
    copts = [
        "-I{}/PublicHeaders/skia".format(package_name()),
    ],
    linkopts = [
        "-Wl,-rpath,@loader_path/Frameworks/libskia.framework",
    ],
    hdrs = glob([
        "PublicHeaders/**/*.h",
    ]),
    includes = [
        "PublicHeaders",
        "PublicHeaders/skia",
    ],
    deps = [
        ":libskia",
    ],
    sdk_frameworks = [
        "Foundation",
    ],
    visibility = [
        "//visibility:public",
    ],
)
