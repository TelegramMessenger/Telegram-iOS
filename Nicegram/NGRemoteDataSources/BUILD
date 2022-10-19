load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "NGRemoteDataSources",
    module_name = "NGRemoteDataSources",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//Nicegram/EsimModule/EsimApiClientDefinition:EsimApiClientDefinition",
        "//Nicegram/EsimModule/SafeExecutor:SafeExecutor",
        "//Nicegram/EsimModule/EsimFeatureAssistant:EsimFeatureAssistant",
        "//Nicegram/EsimModule/EsimFeatureMyEsims:EsimFeatureMyEsims",
        "//Nicegram/EsimModule/EsimFeatureSimOffers:EsimFeatureSimOffers",
        "//Nicegram/NGMappers:NGMappers",
        "//Nicegram/NGModels:NGModels",
    ],
    visibility = ["//visibility:public"],

)
