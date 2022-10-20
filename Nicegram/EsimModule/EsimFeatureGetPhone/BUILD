load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "EsimFeatureGetPhone",
    module_name = "EsimFeatureGetPhone",
    srcs = glob([
        "**/*.swift",
    ]),
    deps = [
        "//Nicegram/EsimModule/EsimApiClientDefinition:EsimApiClientDefinition",
        "//Nicegram/EsimModule/EsimDTO: EsimDTO",
    ],
    visibility = ["//visibility:public"],
)
