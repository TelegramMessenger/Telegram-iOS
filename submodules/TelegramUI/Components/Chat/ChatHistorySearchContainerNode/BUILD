load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ChatHistorySearchContainerNode",
    module_name = "ChatHistorySearchContainerNode",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/AsyncDisplayKit",
        "//submodules/Display",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/Postbox",
        "//submodules/TelegramCore",
        "//submodules/TelegramPresentationData",
        "//submodules/MergeLists",
        "//submodules/AccountContext",
        "//submodules/SearchUI",
        "//submodules/TelegramUIPreferences",
        "//submodules/ListMessageItem",
        "//submodules/TelegramUI/Components/ChatControllerInteraction",
        "//submodules/TelegramUI/Components/Chat/ChatMessageItemView",
    ],
    visibility = [
        "//visibility:public",
    ],
)
