load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "NGLab",
    module_name = "NGLab",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//Nicegram/NGLogging:NGLogging",
        "//Nicegram/NGEnv:NGEnv"
    ],
    visibility = [
        "//visibility:public",
    ],
)
