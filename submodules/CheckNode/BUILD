load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "CheckNode",
    module_name = "CheckNode",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/Display:Display",
        "//submodules/LegacyComponents:LegacyComponents",
    ],
    visibility = [
        "//visibility:public",
    ],
)
