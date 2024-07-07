load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "InteractiveTextComponent",
    module_name = "InteractiveTextComponent",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/AsyncDisplayKit",
        "//submodules/Display",
        "//submodules/ComponentFlow",
        "//submodules/AppBundle",
        "//submodules/TextFormat",
        "//submodules/AccountContext",
        "//submodules/TelegramUI/Components/AnimationCache",
        "//submodules/TelegramUI/Components/MultiAnimationRenderer",
        "//submodules/TelegramCore",
        "//submodules/TelegramUI/Components/EmojiTextAttachmentView",
        "//submodules/TelegramUI/Components/Chat/MessageInlineBlockBackgroundView",
        "//submodules/InvisibleInkDustNode",
    ],
    visibility = [
        "//visibility:public",
    ],
)
