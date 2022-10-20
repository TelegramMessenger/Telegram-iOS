load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "NGMobileDataFormatter",
    module_name = "NGMobileDataFormatter",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//Nicegram/NGLocalization:NGLocalization",
		"//Nicegram/NGModels:NGModels",
        "//Nicegram/NGMoneyFormatter:NGMoneyFormatter",
    ],
    visibility = ["//visibility:public"],

)
