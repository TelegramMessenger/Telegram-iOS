load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "OverlayStatusController",
    module_name = "OverlayStatusController",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    deps = [
        "//submodules/Display:Display",
        "//submodules/OverlayStatusController/Impl:OverlayStatusControllerImpl"
    ],
    visibility = [
        "//visibility:public",
    ],
)
