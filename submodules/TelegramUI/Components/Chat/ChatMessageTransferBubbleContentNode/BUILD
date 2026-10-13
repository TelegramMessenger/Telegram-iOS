load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "ChatMessageTransferBubbleContentNode",
    module_name = "ChatMessageTransferBubbleContentNode",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/AsyncDisplayKit",
        "//submodules/ComponentFlow",
        "//submodules/LottieSettings:LottieSettings",
        "//submodules/Display",
        "//submodules/MetalEngine",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/TelegramCore",
        "//submodules/AccountContext",
        "//submodules/TelegramPresentationData",
        "//submodules/TextFormat",
        "//submodules/LocalizedPeerData",
        "//submodules/TelegramStringFormatting",
        "//submodules/WallpaperBackgroundNode",
        "//submodules/TelegramUI/Components/Chat/ChatMessageBubbleContentNode",
        "//submodules/TelegramUI/Components/Chat/ChatMessageItemCommon",
        "//submodules/TelegramUI/Components/ChatControllerInteraction",
        "//submodules/TelegramUI/Components/Premium/PremiumDiamondComponent",
        "//submodules/TextSelectionNode",
        "//submodules/InvisibleInkDustNode",
        "//submodules/ActivityIndicator",
        "//submodules/WalletContext",
        "//submodules/TelegramUI/Components/Wallet/WalletCardComponent",
    ],
    visibility = [
        "//visibility:public",
    ],
)
