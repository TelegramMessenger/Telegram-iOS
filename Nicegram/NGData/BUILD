load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "NGData",
    module_name = "NGData",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//Nicegram/NGRequests:NGRequests",
        "//Nicegram/NGLogging:NGLogging",
        "//Nicegram/NGEnv:NGEnv"
    ],
    visibility = [
        "//visibility:public",
    ],
)
