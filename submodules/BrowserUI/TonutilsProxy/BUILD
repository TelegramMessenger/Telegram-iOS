load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "TonutilsProxy",
    module_name = "TonutilsProxy",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/BrowserUI/TonutilsProxyBridge",
    ],
    visibility = [
        "//visibility:public",
    ],
)
