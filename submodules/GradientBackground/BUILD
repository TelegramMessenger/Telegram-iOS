load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "GradientBackground",
    module_name = "GradientBackground",
    srcs = glob([
		"Sources/**/*.swift",
    ]),
    deps = [
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/Display:Display",
    ],
    visibility = [
        "//visibility:public",
    ],
)
