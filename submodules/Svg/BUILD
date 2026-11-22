load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "Svg",
    module_name = "Svg",
    srcs = glob([
		"Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Svg/LegacyImpl",
    ],
    visibility = [
        "//visibility:public",
    ],
)
