load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "SolidRoundedButtonComponent",
    module_name = "SolidRoundedButtonComponent",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Display:Display",
        "//submodules/ComponentFlow:ComponentFlow",
        "//submodules/SolidRoundedButtonNode:SolidRoundedButtonNode",
    ],
    visibility = [
        "//visibility:public",
    ],
)
