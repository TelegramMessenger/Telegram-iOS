load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "CompositeTextNode",
    module_name = "CompositeTextNode",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Display",
        "//submodules/AsyncDisplayKit",
    ],
    visibility = [
        "//visibility:public",
    ],
)
