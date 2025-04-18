load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ChatInputTextNode",
    module_name = "ChatInputTextNode",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/AsyncDisplayKit",
        "//submodules/Display",
        "//submodules/AppBundle",
        "//submodules/TelegramUI/Components/Chat/ChatInputTextNode/ChatInputTextViewImpl",
        "//submodules/TelegramUI/Components/Chat/MessageInlineBlockBackgroundView",
        "//submodules/AccountContext",
        "//submodules/TelegramUI/Components/TextNodeWithEntities",
    ],
    visibility = [
        "//visibility:public",
    ],
)
