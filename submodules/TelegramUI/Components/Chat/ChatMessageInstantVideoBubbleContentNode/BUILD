load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ChatMessageInstantVideoBubbleContentNode",
    module_name = "ChatMessageInstantVideoBubbleContentNode",
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
        "//submodules/TelegramUIPreferences",
        "//submodules/ComponentFlow",
        "//submodules/TelegramUI/Components/AudioTranscriptionButtonComponent",
        "//submodules/TelegramUI/Components/Chat/ChatMessageDateAndStatusNode",
        "//submodules/TelegramUI/Components/Chat/ChatMessageBubbleContentNode",
        "//submodules/TelegramUI/Components/Chat/ChatMessageItemCommon",
        "//submodules/TelegramUI/Components/Chat/ChatMessageInteractiveInstantVideoNode",
        "//submodules/TelegramUI/Components/Chat/ChatMessageInteractiveFileNode",
        "//submodules/TelegramUI/Components/ChatControllerInteraction",
    ],
    visibility = [
        "//visibility:public",
    ],
)
