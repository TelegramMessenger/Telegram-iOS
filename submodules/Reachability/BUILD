load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "Reachability",
    module_name = "Reachability",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Reachability/LegacyReachability:LegacyReachability",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
    ],
    visibility = [
        "//visibility:public",
    ],
)
