load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ImageTransparency",
    module_name = "ImageTransparency",
    srcs = glob([
		"Sources/**/*.swift",
    ]),
    copts = [
        #"-warnings-as-errors",
    ],
    deps = [
    	"//submodules/Display:Display",
    ],
    visibility = [
        "//visibility:public",
    ],
)
