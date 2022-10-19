load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "EsimApiClient",
    module_name = "EsimApiClient",
    srcs = glob([
        "**/*.swift",
    ]),
    visibility = ["//visibility:public"],
    deps = [
        "//Nicegram/EsimModule/EsimApiClientDefinition",
        "//Nicegram/EsimModule/EsimAuth",
		"//Nicegram/EsimModule/EsimLogging",
        "//Vendor/DeviceKit:DeviceKit",
    ],
)
