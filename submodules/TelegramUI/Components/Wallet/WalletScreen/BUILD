load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_unit_test")
load("@build_bazel_rules_apple//apple/testing/default_runner:ios_test_runner.bzl", "ios_test_runner")

swift_library(
    name = "WalletScreen",
    module_name = "WalletScreen",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/LottieBinding",
        "//submodules/TelegramUI/Components/LottieComponent",
        "//submodules/AsyncDisplayKit",
        "//submodules/Display",
        "//submodules/AccountContext",
        "//submodules/TelegramCore",
        "//submodules/TelegramNotices",
        "//submodules/TooltipUI",
        "//submodules/TelegramPresentationData",
        "//submodules/PresentationDataUtils",
        "//submodules/TelegramStringFormatting",
        "//submodules/TextFormat",
        "//submodules/ComponentFlow",
        "//submodules/Components/ViewControllerComponent",
        "//submodules/Components/MultilineTextComponent",
        "//submodules/Components/BundleIconComponent",
        "//submodules/TelegramUI/Components/NavigationBarComponent",
        "//submodules/TelegramUI/Components/EdgeEffect",
        "//submodules/TelegramUI/Components/ButtonComponent",
        "//submodules/TelegramUI/Components/ListSectionComponent",
        "//submodules/TelegramUI/Components/ListActionItemComponent",
        "//submodules/TelegramUI/Components/Gifts/InfoParagraphComponent",
        "//submodules/TelegramUI/Components/Gifts/GiftItemComponent",
        "//submodules/TelegramUI/Components/GlassBackgroundComponent",
        "//submodules/TelegramUI/Components/HorizontalTabsComponent",
        "//submodules/TelegramUI/Components/TextFieldComponent",
        "//submodules/TelegramUI/Components/ContextControllerImpl",
        "//submodules/QrCodeUI",
        "//submodules/ContextUI",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/UndoUI",
        "//submodules/SettingsUI",
        "//submodules/TelegramUI/Components/Wallet/WalletCardComponent",
        "//submodules/TelegramUI/Components/Premium/PremiumDiamondComponent",
        "//submodules/WalletContext",
        "//submodules/TelegramUI/Components/Wallet/WalletGiftStickerMediaComponent",
        "//submodules/PasscodeCore",
        "//submodules/Markdown",
        "//submodules/TelegramUI/Components/Wallet/WalletPeerSelectionScreen",
        "//submodules/TelegramUI/Components/Wallet/WalletSendScreen",
        "//submodules/TelegramUI/Components/Wallet/WalletCollectibleHeaderComponent",
        "//submodules/TelegramUI/Components/Wallet/WalletTransactionItemComponent",
        "//submodules/TelegramUI/Components/Wallet/WalletTransactionScreen",
        "//submodules/TelegramUI/Components/Wallet/WalletAuthorizationUI",
    ],
    visibility = [
        "//visibility:public",
    ],
)

swift_library(
    name = "WalletStickerPlacementTestsLib",
    testonly = True,
    srcs = ["Sources/WalletStickerPlacement.swift", "//submodules/TelegramUI/Components/Wallet/WalletGiftStickerMediaComponent:Sources/WalletGiftStickerCutout.swift", "Tests/WalletStickerPlacementTests.swift", "//submodules/TelegramUI/Components/Wallet/WalletCardComponent:Sources/WalletStickerAnimation.swift"],
    deps = ["//submodules/WalletContext"],
)
ios_test_runner(name = "WalletStickerPlacementTestRunner", device_type = "iPhone 17", os_version = "26.5")
ios_unit_test(
    name = "WalletStickerPlacementTests",
    minimum_os_version = "15.0",
    runner = ":WalletStickerPlacementTestRunner",
    deps = [":WalletStickerPlacementTestsLib"],
)
