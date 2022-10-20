load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "NGApiClient",
    module_name = "NGApiClient",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
		"//Nicegram/EsimModule/EsimApiClient",
        "//Nicegram/NGAppCache:NGAppCache",
        "//Nicegram/NGEnv:NGEnv",
    ],
    visibility = ["//visibility:public"],

)
