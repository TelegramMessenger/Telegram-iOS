load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "HexColor",
    module_name = "HexColor",
    srcs = glob([
		"Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
	    "//submodules/TextFormat:TextFormat",
    ],
    visibility = [
        "//visibility:public",
    ],
)
