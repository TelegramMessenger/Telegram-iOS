load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "TPAuth",
    module_name = "TPAuth",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//submodules/BuildConfig:BuildConfig",
    ],
    copts = [
        "-warnings-as-errors",
    ],
    visibility = [
        "//visibility:public",
    ],
)
