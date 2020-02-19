load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

filegroup(
    name = "OverlayStatusControllerResources",
    srcs = glob([
        "Resources/**/*",
    ], exclude = ["Resources/**/.*"]),
)

swift_library(
    name = "OverlayStatusController",
    module_name = "OverlayStatusController",
    data = [
        ":OverlayStatusControllerResources",
    ],
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
