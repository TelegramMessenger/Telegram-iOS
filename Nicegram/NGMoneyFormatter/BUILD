load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "NGMoneyFormatter",
    module_name = "NGMoneyFormatter",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
		"//Nicegram/NGModels:NGModels",
    ],
    visibility = ["//visibility:public"],

)
