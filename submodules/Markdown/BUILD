load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "Markdown",
    module_name = "Markdown",
    srcs = glob([
        "Source/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    visibility = [
        "//visibility:public",
    ],
)
