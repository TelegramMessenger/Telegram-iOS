load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

# Zero dependencies is the point: AccountContext needs LottieRenderingSettings
# and must not gain an edge to two rasterizers, and LottieComponent depends on
# neither TelegramCore nor AccountContext today.
swift_library(
    name = "LottieSettings",
    module_name = "LottieSettings",
    srcs = glob(["Sources/**/*.swift"]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [],
    visibility = [
        "//visibility:public",
    ],
)
