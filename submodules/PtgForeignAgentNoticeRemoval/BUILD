load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "PtgForeignAgentNoticeRemoval",
    module_name = "PtgForeignAgentNoticeRemoval",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Postbox:Postbox",
        "//submodules/TelegramCore:TelegramCore",
    ],
    visibility = [
        "//visibility:public",
    ],
)
