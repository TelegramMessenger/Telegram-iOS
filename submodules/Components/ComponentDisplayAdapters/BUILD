load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ComponentDisplayAdapters",
    module_name = "ComponentDisplayAdapters",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Display:Display",
        "//submodules/ComponentFlow:ComponentFlow",
    ],
    visibility = [
        "//visibility:public",
    ],
)
