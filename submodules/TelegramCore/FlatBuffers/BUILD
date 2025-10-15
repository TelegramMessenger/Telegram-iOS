load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "FlatBuffers",
    module_name = "FlatBuffers",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-suppress-warnings",
    ],
    deps = [
    ],
    visibility = [
        "//visibility:public",
    ],
)
