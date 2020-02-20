load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "WebUI",
    module_name = "WebUI",
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
