load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "WalletCollectibleScreen",
    module_name = "WalletCollectibleScreen",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/AccountContext",
        "//submodules/ComponentFlow",
        "//submodules/Components/BundleIconComponent",
        "//submodules/Components/MultilineTextComponent",
        "//submodules/Components/BalancedTextComponent",
        "//submodules/Components/SheetComponent",
        "//submodules/Components/ViewControllerComponent",
        "//submodules/ContextUI",
        "//submodules/Display",
        "//submodules/PasscodeCore",
        "//submodules/PresentationDataUtils",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/TelegramCore",
        "//submodules/TelegramPresentationData",
        "//submodules/TelegramStringFormatting",
        "//submodules/TextFormat",
        "//submodules/TelegramUI/Components/AvatarComponent",
        "//submodules/TelegramUI/Components/ButtonComponent",
        "//submodules/TelegramUI/Components/Gifts/TableComponent",
        "//submodules/TelegramUI/Components/GlassControls",
        "//submodules/TelegramUI/Components/Wallet/WalletCollectibleHeaderComponent",
        "//submodules/TelegramUI/Components/Wallet/WalletAuthorizationUI",
        "//submodules/TelegramUI/Components/Wallet/WalletPagerComponent",
        "//submodules/TelegramUI/Components/Wallet/WalletPeerSelectionScreen",
        "//submodules/WalletContext",
        "//submodules/TooltipUI",
        "//submodules/UndoUI",
    ],
    visibility = [
        "//visibility:public",
    ],
)
