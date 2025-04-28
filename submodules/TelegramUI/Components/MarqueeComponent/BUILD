load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "MarqueeComponent",
    module_name = "MarqueeComponent",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Display",
        "//submodules/ComponentFlow",
        "//submodules/SSignalKit/SwiftSignalKit",
    ],
    visibility = [
        "//visibility:public",
    ],
)
