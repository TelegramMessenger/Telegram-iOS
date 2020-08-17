load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ImageCompression",
    module_name = "ImageCompression",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//submodules/MozjpegBinding:MozjpegBinding",
    ],
    visibility = [
        "//visibility:public",
    ],
)
