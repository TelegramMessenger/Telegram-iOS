load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "GraphCore",
    module_name = "GraphCore",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Display:Display",
    ],
    visibility = [
        "//visibility:public",
    ],
)
