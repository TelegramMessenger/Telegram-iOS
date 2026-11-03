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
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/AppBundle",
        "//submodules/TelegramCore",
        "//submodules/TelegramUI/Components/Chat/ChatInputTextNode/ChatInputTextViewImpl",
        "//submodules/TelegramUI/Components/Chat/MessageInlineBlockBackgroundView",
        "//submodules/AccountContext",
        "//submodules/TelegramUI/Components/TextNodeWithEntities",
        "//submodules/InvisibleInkDustNode",
        "//submodules/TelegramUI/Components/EmojiTextAttachmentView",
        "//submodules/TelegramUI/Components/RichTextEditor:RichTextEditorCore",
        "//submodules/TelegramUI/Components/RichTextEditor:RichTextEditorUIKit",
    ],
    visibility = [
        "//visibility:public",
    ],
)
