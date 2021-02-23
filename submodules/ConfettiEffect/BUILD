load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ConfettiEffect",
    module_name = "ConfettiEffect",
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
