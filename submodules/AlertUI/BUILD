load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "AlertUI",
    module_name = "AlertUI",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//submodules/Display:Display",
    ],
    visibility = [
        "//visibility:public",
    ],
)
