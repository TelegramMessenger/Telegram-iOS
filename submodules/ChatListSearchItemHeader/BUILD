load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ChatListSearchItemHeader",
    module_name = "ChatListSearchItemHeader",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Display:Display",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/ListSectionHeaderNode:ListSectionHeaderNode",
    ],
    visibility = [
        "//visibility:public",
    ],
)
