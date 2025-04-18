load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "PremiumPeerShortcutComponent",
    module_name = "PremiumPeerShortcutComponent",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Display",
        "//submodules/ComponentFlow",
        "//submodules/TelegramCore",
        "//submodules/TelegramPresentationData",
        "//submodules/AvatarNode",
        "//submodules/Components/MultilineTextComponent",
        "//submodules/AccountContext",
        "//submodules/TelegramUI/Components/EmojiTextAttachmentView",
        "//submodules/TextFormat",
    ],
    visibility = [
        "//visibility:public",
    ],
)
