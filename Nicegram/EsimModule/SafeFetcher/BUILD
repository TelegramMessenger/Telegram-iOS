load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "SafeFetcher",
    module_name = "SafeFetcher",
    srcs = glob([
        "**/*.swift",
    ]),
    visibility = ["//visibility:public"],
    deps = [
		"//Nicegram/EsimModule/ThreadSafeDictionary",
    ],
)
