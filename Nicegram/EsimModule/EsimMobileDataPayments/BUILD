load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "EsimMobileDataPayments",
    module_name = "EsimMobileDataPayments",
    srcs = glob([
        "**/*.swift",
    ]),
    deps = [
        "//Nicegram/EsimModule/EsimApiClientDefinition:EsimApiClientDefinition",
        "//Nicegram/EsimModule/EsimPayments:EsimPayments",
    ],
    visibility = ["//visibility:public"],
)
