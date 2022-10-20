load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "RangeSet",
    module_name = "RangeSet",
    srcs = glob([
		"Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    visibility = [
        "//visibility:public",
    ],
)
