load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "NGMappers",
    module_name = "NGMappers",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//Nicegram/EsimModule/EsimDTO:EsimDTO",
        "//Nicegram/NGModels:NGModels",
    ],
    visibility = ["//visibility:public"],

)
