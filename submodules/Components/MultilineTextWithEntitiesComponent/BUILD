load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "MultilineTextWithEntitiesComponent",
    module_name = "MultilineTextWithEntitiesComponent",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Display:Display",
        "//submodules/ComponentFlow:ComponentFlow",
        "//submodules/Markdown:Markdown",
        "//submodules/TextFormat:TextFormat",
        "//submodules/AccountContext:AccountContext",
        "//submodules/TelegramUI/Components/EmojiTextAttachmentView:EmojiTextAttachmentView",
        "//submodules/TelegramUI/Components/AnimationCache:AnimationCache",
        "//submodules/TelegramUI/Components/MultiAnimationRenderer:MultiAnimationRenderer",
        "//submodules/TelegramUI/Components/TextNodeWithEntities:TextNodeWithEntities",
    ],
    visibility = [
        "//visibility:public",
    ],
)
