load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "AnimatableProperty",
    module_name = "AnimatableProperty",
    srcs = glob([
		"Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Display",
        "//submodules/ComponentFlow",
    ],
    visibility = [
        "//visibility:public",
    ],
)
