load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "GlassButtonNode",
    module_name = "GlassButtonNode",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
    	"//submodules/Display:Display",
    ],
    visibility = [
        "//visibility:public",
    ],
)
