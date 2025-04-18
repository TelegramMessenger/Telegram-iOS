load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ContextUI",
    module_name = "ContextUI",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/Display:Display",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/TextSelectionNode:TextSelectionNode",
        "//submodules/AppBundle:AppBundle",
        "//submodules/AccountContext:AccountContext",
        "//submodules/ReactionSelectionNode:ReactionSelectionNode",
        "//submodules/Markdown:Markdown",
        "//submodules/TextFormat:TextFormat",
        "//submodules/TelegramUI/Components/TextNodeWithEntities:TextNodeWithEntities",
        "//submodules/TelegramUI/Components/EntityKeyboard:EntityKeyboard",
        "//submodules/UndoUI:UndoUI",
        "//submodules/AnimationUI:AnimationUI",
        "//submodules/ComponentFlow",
        "//submodules/Components/ComponentDisplayAdapters",
        "//submodules/TelegramUI/Components/TabSelectorComponent",
        "//submodules/TelegramUI/Components/LottieComponent",
        "//submodules/TelegramUI/Components/PlainButtonComponent",
        "//submodules/UIKitRuntimeUtils",
        "//submodules/TelegramUI/Components/EmojiStatusComponent",
    ],
    visibility = [
        "//visibility:public",
    ],
)
