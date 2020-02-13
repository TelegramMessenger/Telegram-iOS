load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ProgressNavigationButtonNode",
    module_name = "ProgressNavigationButtonNode",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//submodules/Display:Display",
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/ActivityIndicator:ActivityIndicator",
    ],
    visibility = [
        "//visibility:public",
    ],
)
