load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "WidgetItems",
    module_name = "WidgetItems",
    srcs = glob([
		"Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    visibility = [
        "//visibility:public",
    ],
)

swift_library(
    name = "WidgetItems_iOS14",
    module_name = "WidgetItems_iOS14",
    srcs = glob([
		"Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    visibility = [
        "//visibility:public",
    ],
)
