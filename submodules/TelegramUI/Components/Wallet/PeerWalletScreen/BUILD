load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "PeerWalletScreen",
    module_name = "PeerWalletScreen",
    srcs = glob(["Sources/**/*.swift"]),
    copts = ["-warnings-as-errors"],
    deps = [
        "//submodules/AccountContext",
        "//submodules/ComponentFlow",
        "//submodules/Components/ViewControllerComponent",
        "//submodules/Display",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/TelegramCore",
        "//submodules/TelegramPresentationData",
        "//submodules/TelegramStringFormatting",
        "//submodules/PresentationDataUtils",
        "//submodules/TelegramUI/Components/ButtonComponent",
        "//submodules/Components/BalancedTextComponent",
        "//submodules/TelegramUI/Components/PlainButtonComponent",
        "//submodules/TelegramUI/Components/Wallet/WalletCardComponent",
        "//submodules/WalletContext",
        "//submodules/TelegramUI/Components/Wallet/WalletGiftStickerMediaComponent",
    ],
    visibility = ["//visibility:public"],
)
