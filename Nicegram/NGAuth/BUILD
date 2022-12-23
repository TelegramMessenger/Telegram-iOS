load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "NGAuth",
    module_name = "NGAuth",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//Nicegram/EsimModule/EsimAuth:EsimAuth",
        "//Nicegram/NGCore:NGCore",
        "//Nicegram/NGEnv:NGEnv",
        "//Nicegram/NGTelegramRepo:NGTelegramRepo",
        "//Nicegram/NGUtils:NGUtils",
    ],
    visibility = ["//visibility:public"],

)
