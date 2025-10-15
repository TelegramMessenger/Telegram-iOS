load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ChatMessageNotificationItem",
    module_name = "ChatMessageNotificationItem",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/AsyncDisplayKit",
        "//submodules/Display",
        "//submodules/Postbox",
        "//submodules/TelegramCore",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/TelegramPresentationData",
        "//submodules/TelegramUIPreferences",
        "//submodules/AvatarNode",
        "//submodules/AccountContext",
        "//submodules/LocalizedPeerData",
        "//submodules/StickerResources",
        "//submodules/PhotoResources",
        "//submodules/TelegramStringFormatting",
        "//submodules/TextFormat",
        "//submodules/InvisibleInkDustNode",
        "//submodules/TelegramUI/Components/TextNodeWithEntities",
        "//submodules/TelegramUI/Components/AnimationCache",
        "//submodules/TelegramUI/Components/MultiAnimationRenderer",
        "//submodules/Components/MultilineTextComponent",
        "//submodules/Components/BundleIconComponent",
        "//submodules/TelegramUI/Components/PlainButtonComponent",
    ],
    visibility = [
        "//visibility:public",
    ],
)
