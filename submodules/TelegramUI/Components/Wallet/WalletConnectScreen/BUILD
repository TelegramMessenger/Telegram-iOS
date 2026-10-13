load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "WalletConnectScreen",
    module_name = "WalletConnectScreen",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Display",
        "//submodules/AlertUI",
        "//submodules/AccountContext",
        "//submodules/TelegramCore",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/TelegramPresentationData",
        "//submodules/PresentationDataUtils",
        "//submodules/TelegramStringFormatting",
        "//submodules/ComponentFlow",
        "//submodules/Components/ViewControllerComponent",
        "//submodules/Components/SheetComponent",
        "//submodules/Components/ResizableSheetComponent",
        "//submodules/TelegramUI/Components/NavigationStackComponent",
        "//submodules/Components/BalancedTextComponent",
        "//submodules/Components/BundleIconComponent",
        "//submodules/Components/MultilineTextComponent",
        "//submodules/TelegramUI/Components/ScrollComponent",
        "//submodules/TextSelectionNode",
        "//submodules/Pasteboard",
        "//submodules/TelegramUI/Components/ListActionItemComponent",
        "//submodules/TelegramUI/Components/ListSectionComponent",
        "//submodules/TelegramUI/Components/GlassBarButtonComponent",
        "//submodules/TelegramUI/Components/ButtonComponent",
        "//submodules/WalletContext",
        "//submodules/TelegramUI/Components/Wallet/WalletCardComponent",
        "//submodules/TelegramUI/Components/Wallet/WalletTransactionItemComponent",
        "//submodules/UndoUI",
    ],
    visibility = [
        "//visibility:public",
    ],
)
