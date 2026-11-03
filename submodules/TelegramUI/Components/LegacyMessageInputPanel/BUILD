load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "LegacyMessageInputPanel",
    module_name = "LegacyMessageInputPanel",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/Display",
        "//submodules/TelegramCore",
        "//submodules/AccountContext",
        "//submodules/LegacyComponents",
        "//submodules/ChatPresentationInterfaceState",
        "//submodules/ComponentFlow",
        "//submodules/TelegramPresentationData",
        "//submodules/ContextUI",
        "//submodules/TooltipUI",
        "//submodules/UndoUI",
        "//submodules/TelegramUI/Components/ChatEntityKeyboardInputNode",
        "//submodules/TelegramUI/Components/MessageInputPanelComponent",
        "//submodules/TelegramNotices",
        "//submodules/TextFormat",
        "//submodules/TelegramUIPreferences",
        "//submodules/Pasteboard",
        "//submodules/TelegramUI/Components/Chat/ChatRichTextEditorComposer",
    ],
    visibility = [
        "//visibility:public",
    ],
)
