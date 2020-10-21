load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "AnimatedNavigationStripeNode",
    module_name = "AnimatedNavigationStripeNode",
    srcs = glob([
		"Sources/**/*.swift",
    ]),
    deps = [
        "//submodules/Display:Display",
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
    ],
    visibility = [
        "//visibility:public",
    ],
)
