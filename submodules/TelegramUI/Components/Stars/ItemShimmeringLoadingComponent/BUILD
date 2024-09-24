load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ItemShimmeringLoadingComponent",
    module_name = "ItemShimmeringLoadingComponent",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/AsyncDisplayKit",
        "//submodules/Display",
        "//submodules/Postbox",
        "//submodules/ComponentFlow",
        "//submodules/AppBundle",
        "//submodules/Components/HierarchyTrackingLayer",
        "//submodules/TelegramUI/Components/TextLoadingEffect",
    ],
    visibility = [
        "//visibility:public",
    ],
)
