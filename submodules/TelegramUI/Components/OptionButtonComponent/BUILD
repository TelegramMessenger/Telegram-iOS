load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "OptionButtonComponent",
    module_name = "OptionButtonComponent",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Display",
        "//submodules/ComponentFlow",
        "//submodules/AppBundle",
    ],
    visibility = [
        "//visibility:public",
    ],
)
