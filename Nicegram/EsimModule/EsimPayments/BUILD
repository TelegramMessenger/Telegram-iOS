load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "EsimPayments",
    module_name = "EsimPayments",
    srcs = glob([
        "**/*.swift",
    ]),
    deps = [
		"//third-party/EcommpaySDK:ecommpaySDK",
    ],
    visibility = ["//visibility:public"],
)
