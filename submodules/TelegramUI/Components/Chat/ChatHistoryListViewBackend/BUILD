load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ChatHistoryListViewBackend",
    module_name = "ChatHistoryListViewBackend",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/Display:Display",
        "//submodules/ComponentFlow:ComponentFlow",
        "//submodules/Components/ComponentDisplayAdapters:ComponentDisplayAdapters",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/TelegramUI/Components/CoreList:CoreList",
        "//submodules/TelegramUI/Components/CoreListComponentHost",
        "//submodules/TelegramUI/Components/Chat/ChatMessageItem",
        "//submodules/TelegramUI/Components/Chat/ChatMessageItemImpl",
        "//submodules/TelegramUI/Components/Chat/ChatMessageItemView",
        "//submodules/TelegramCore:TelegramCore",
    ],
    visibility = [
        "//visibility:public",
    ],
)
