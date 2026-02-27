load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ContextControllerImpl",
    module_name = "ContextControllerImpl",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/AccountContext",
        "//submodules/TelegramUI/Components/AnimationCache",
        "//submodules/AnimationUI",
        "//submodules/AppBundle",
        "//submodules/AsyncDisplayKit",
        "//submodules/Components/ComponentDisplayAdapters",
        "//submodules/ComponentFlow",
        "//submodules/ContextUI",
        "//submodules/Display",
        "//submodules/TelegramUI/Components/EmojiStatusComponent",
        "//submodules/TelegramUI/Components/EntityKeyboard",
        "//submodules/TelegramUI/Components/GlassBackgroundComponent",
        "//submodules/TelegramUI/Components/LottieComponent",
        "//submodules/Markdown",
        "//submodules/TelegramUI/Components/MultiAnimationRenderer",
        "//submodules/ReactionSelectionNode",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/TelegramCore",
        "//submodules/TelegramPresentationData",
        "//submodules/TextFormat",
        "//submodules/TelegramUI/Components/TextNodeWithEntities",
        "//submodules/TextSelectionNode",
        "//submodules/UIKitRuntimeUtils",
        "//submodules/UndoUI",
    ],
    visibility = [
        "//visibility:public",
    ],
)
