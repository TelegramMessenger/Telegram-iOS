load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "NGAuthService",
    module_name = "NGAuthService",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//Nicegram/EsimModule/EsimAuth",
        "//Nicegram/EsimModule/EsimApiClient"
    ],
    visibility = ["//visibility:public"],

)
