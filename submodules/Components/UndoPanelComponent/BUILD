load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "UndoPanelComponent",
    module_name = "UndoPanelComponent",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/ComponentFlow:ComponentFlow",
    ],
    visibility = [
        "//visibility:public",
    ],
)
