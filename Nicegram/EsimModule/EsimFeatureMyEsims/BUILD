load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "EsimFeatureMyEsims",
    module_name = "EsimFeatureMyEsims",
    srcs = glob([
        "**/*.swift",
    ]),
    visibility = ["//visibility:public"],
    deps = [
        "//Nicegram/EsimModule/EsimApiClientDefinition:EsimApiClientDefinition",
        "//Nicegram/EsimModule/EsimDTO:EsimDTO",
    ],
)
