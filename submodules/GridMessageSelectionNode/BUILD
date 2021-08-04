load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "GridMessageSelectionNode",
    module_name = "GridMessageSelectionNode",
    srcs = glob([
		"Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/Display:Display",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/CheckNode:CheckNode",
    ],
    visibility = [
        "//visibility:public",
    ],
)
