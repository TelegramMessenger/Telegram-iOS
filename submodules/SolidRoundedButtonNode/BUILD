load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "SolidRoundedButtonNode",
    module_name = "SolidRoundedButtonNode",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/Display:Display",
        "//submodules/Components/HierarchyTrackingLayer:HierarchyTrackingLayer",
    ],
    visibility = [
        "//visibility:public",
    ],
)
