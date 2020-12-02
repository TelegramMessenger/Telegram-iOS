load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "MessageHistoryReadStateTable",
    module_name = "MessageHistoryReadStateTable",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//submodules/Database/ValueBox:ValueBox",
        "//submodules/Database/Table:Table",
        "//submodules/Database/PostboxDataTypes:PostboxDataTypes",
    ],
    visibility = [
        "//visibility:public",
    ],
)
