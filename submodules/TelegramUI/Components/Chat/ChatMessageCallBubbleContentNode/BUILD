load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ChatMessageCallBubbleContentNode",
    module_name = "ChatMessageCallBubbleContentNode",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/AsyncDisplayKit",
        "//submodules/Display",
        "//submodules/TelegramCore",
        "//submodules/Postbox",
        "//submodules/TelegramPresentationData",
        "//submodules/AppBundle",
        "//submodules/TelegramUI/Components/Chat/ChatMessageBubbleContentNode",
        "//submodules/TelegramUI/Components/Chat/ChatMessageItemCommon",
        "//submodules/TelegramUI/Components/Chat/ChatMessageDateAndStatusNode",
        "//submodules/AnimatedAvatarSetNode",
        "//submodules/AvatarNode",
    ],
    visibility = [
        "//visibility:public",
    ],
)
