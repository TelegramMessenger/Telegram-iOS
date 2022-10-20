load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "NGLocalization",
    module_name = "NGLocalization",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
		"//Vendor/CrowdinSDK:CrowdinSDK",
    ],
    visibility = ["//visibility:public"],

)
