load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "EditableChatTextNode",
    module_name = "EditableChatTextNode",
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
