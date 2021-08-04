load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ImageBlur",
    module_name = "ImageBlur",
    srcs = glob([
		"Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
	    "//submodules/FastBlur:FastBlur",
    ],
    visibility = [
        "//visibility:public",
    ],
)
