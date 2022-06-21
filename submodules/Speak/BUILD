load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "Speak",
    module_name = "Speak",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Display:Display",
        "//submodules/AccountContext:AccountContext",
    ],
    visibility = [
        "//visibility:public",
    ],
)
