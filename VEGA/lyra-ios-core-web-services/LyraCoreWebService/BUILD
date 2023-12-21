load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "LyraCoreWebService",
    module_name = "CoreWebService",
    srcs = glob([
        "CoreWebService/**/*.swift",
    ]),
    copts = [
    ],
    deps = [
	"//VEGA/SimpleKeychain"
    ],
    visibility = [
        "//visibility:public",
    ],
)
