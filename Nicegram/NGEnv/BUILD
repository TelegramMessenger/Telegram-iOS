load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "NGEnv",
    module_name = "NGEnv",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//submodules/BuildConfig:BuildConfig"
    ],
    visibility = [
        "//visibility:public",
    ],
)
