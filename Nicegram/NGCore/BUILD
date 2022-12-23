load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "NGCore",
    module_name = "NGCore",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//Nicegram/EsimModule/EsimApiClient:EsimApiClient",
        "//Nicegram/NGLocalization:NGLocalization",
        "//Nicegram/NGModels:NGModels",
    ],
    visibility = [
        "//visibility:public",
    ],
)
