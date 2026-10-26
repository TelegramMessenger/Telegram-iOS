load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "WalletSettingsScreen",
    module_name = "WalletSettingsScreen",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/PasscodeCore",
        "//submodules/AccountContext",
        "//submodules/ComponentFlow",
        "//submodules/Components/MultilineTextComponent",
        "//submodules/Components/ViewControllerComponent",
        "//submodules/Display",
        "//submodules/PresentationDataUtils",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/TelegramNotices",
        "//submodules/TelegramPresentationData",
        "//submodules/TelegramStringFormatting",
        "//submodules/TelegramUI/Components/ListActionItemComponent",
        "//submodules/TelegramUI/Components/ListSectionComponent",
        "//submodules/TelegramUI/Components/AlertComponent",
        "//submodules/TelegramUI/Components/AlertComponent/AlertCheckComponent",
        "//submodules/UndoUI",
        "//submodules/WalletContext",
        "//submodules/TelegramUI/Components/Wallet/WalletAuthorizationUI",
        "//submodules/TelegramUI/Components/Wallet/WalletImportScreen",
    ],
    visibility = [
        "//visibility:public",
    ],
)
