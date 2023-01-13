load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "PtgForeignAgentNoticeSearchFiltering",
    module_name = "PtgForeignAgentNoticeSearchFiltering",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Postbox:Postbox",
        "//submodules/Display:Display",
        "//submodules/PtgForeignAgentNoticeRemoval:PtgForeignAgentNoticeRemoval",
    ],
    visibility = [
        "//visibility:public",
    ],
)
