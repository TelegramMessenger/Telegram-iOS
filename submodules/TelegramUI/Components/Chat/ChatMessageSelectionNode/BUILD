load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ChatMessageSelectionNode",
    module_name = "ChatMessageSelectionNode",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/AsyncDisplayKit",
        "//submodules/TelegramPresentationData",
        "//submodules/CheckNode",
        "//submodules/TelegramCore",
    ],
    visibility = [
        "//visibility:public",
    ],
)
