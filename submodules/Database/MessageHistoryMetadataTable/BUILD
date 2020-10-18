load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "MessageHistoryMetadataTable",
    module_name = "MessageHistoryMetadataTable",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//submodules/Database/ValueBox:ValueBox",
        "//submodules/Database/Table:Table",
        "//submodules/Database/PostboxDataTypes:PostboxDataTypes",
        "//submodules/Database/PostboxCoding:PostboxCoding",
    ],
    visibility = [
        "//visibility:public",
    ],
)
