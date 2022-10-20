load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "EsimMobileDataPurchaseProvider",
    module_name = "EsimMobileDataPurchaseProvider",
    srcs = glob([
        "**/*.swift",
    ]),
    deps = [
        "//Nicegram/EsimModule/EsimApiClientDefinition:EsimApiClientDefinition",
        "//Nicegram/EsimModule/EsimDTO:EsimDTO",
        "//Nicegram/EsimModule/EsimMobileDataPayments:EsimMobileDataPayments",
    ],
    visibility = ["//visibility:public"],
)
