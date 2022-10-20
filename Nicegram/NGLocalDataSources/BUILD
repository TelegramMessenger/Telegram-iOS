load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "NGLocalDataSources",
    module_name = "NGLocalDataSources",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//Nicegram/EsimModule/FileStorage:FileStorage",
        "//Nicegram/NGModels:NGModels",
    ],
    visibility = ["//visibility:public"],

)
