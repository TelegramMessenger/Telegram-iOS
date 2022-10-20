load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "NGRepositories",
    module_name = "NGRepositories",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//Nicegram/NGLocalDataSources:NGLocalDataSources",
        "//Nicegram/NGModels:NGModels",
        "//Nicegram/NGRemoteDataSources:NGRemoteDataSources",
    ],
    visibility = ["//visibility:public"],

)
