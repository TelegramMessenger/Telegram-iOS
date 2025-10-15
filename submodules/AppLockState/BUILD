load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "AppLockState",
    module_name = "AppLockState",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//submodules/MonotonicTime:MonotonicTime",
    ],
    visibility = [
        "//visibility:public",
    ],
)
