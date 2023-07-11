load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "AvatarStoryIndicatorComponent",
    module_name = "AvatarStoryIndicatorComponent",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Display",
        "//submodules/ComponentFlow",
        "//submodules/TelegramPresentationData",
        "//submodules/Components/HierarchyTrackingLayer",
    ],
    visibility = [
        "//visibility:public",
    ],
)
