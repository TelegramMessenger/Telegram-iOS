load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "RadialStatusNode",
    module_name = "RadialStatusNode",
    srcs = glob([
		"Sources/**/*.swift",
    ]),
    deps = [
        "//submodules/Display:Display",
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/LegacyComponents:LegacyComponents",
    ],
    visibility = [
        "//visibility:public",
    ],
)
