load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ToastComponent",
    module_name = "ToastComponent",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Display",
        "//submodules/ComponentFlow",
        "//submodules/Components/ComponentDisplayAdapters",
    ],
    visibility = [
        "//visibility:public",
    ],
)
