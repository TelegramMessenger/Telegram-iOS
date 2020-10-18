load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "PostboxDataTypes",
    module_name = "PostboxDataTypes",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//submodules/Database/ValueBox:ValueBox",
        "//submodules/Database/PostboxCoding:PostboxCoding",
    ],
    visibility = [
        "//visibility:public",
    ],
)
