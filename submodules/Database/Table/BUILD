load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "Table",
    module_name = "Table",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//submodules/Database/ValueBox:ValueBox",
    ],
    visibility = [
        "//visibility:public",
    ],
)
