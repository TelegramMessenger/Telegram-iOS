load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "NGDeviceCheck",
    module_name = "NGDeviceCheck",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//Nicegram/NGLogging:NGLogging",
    ],
    visibility = [
        "//visibility:public",
    ],
)
