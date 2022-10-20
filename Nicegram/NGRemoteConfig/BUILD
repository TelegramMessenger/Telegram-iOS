load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "NGRemoteConfig",
    module_name = "NGRemoteConfig",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "@FirebaseSDK//:FirebaseRemoteConfig",
        "//Nicegram/EsimModule/SafeExecutor:SafeExecutor",
        "//Nicegram/NGEnv:NGEnv",
    ],
    visibility = ["//visibility:public"],

)
