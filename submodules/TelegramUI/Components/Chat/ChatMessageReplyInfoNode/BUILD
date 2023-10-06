load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ChatMessageReplyInfoNode",
    module_name = "ChatMessageReplyInfoNode",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/AsyncDisplayKit",
        "//submodules/TelegramPresentationData",
        "//submodules/ChatPresentationInterfaceState",
    ],
    visibility = [
        "//visibility:public",
    ],
)
