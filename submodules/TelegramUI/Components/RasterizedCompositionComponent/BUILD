load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "RasterizedCompositionComponent",
    module_name = "RasterizedCompositionComponent",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/AsyncDisplayKit",
        "//submodules/Display",
        "//submodules/ComponentFlow",
        "//submodules/UIKitRuntimeUtils",
    ],
    visibility = [
        "//visibility:public",
    ],
)
