load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "EsimLogging",
    module_name = "EsimLogging",
    srcs = glob([
        "**/*.swift",
    ]),
    visibility = ["//visibility:public"],
    deps = [
        "//Nicegram/EsimModule/EsimApiClientDefinition",
    ],
)
