load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "PersistentStringHash",
    module_name = "PersistentStringHash",
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
