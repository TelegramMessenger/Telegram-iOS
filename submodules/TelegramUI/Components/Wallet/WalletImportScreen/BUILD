load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "WalletImportScreen",
    module_name = "WalletImportScreen",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/PasscodeCore",
        "//submodules/Display",
        "//submodules/LottieSettings:LottieSettings",
        "//submodules/AccountContext",
        "//submodules/Markdown",
        "//submodules/ComponentFlow",
        "//submodules/TelegramPresentationData",
        "//submodules/PresentationDataUtils",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/Components/ViewControllerComponent",
        "//submodules/Components/MultilineTextComponent",
        "//submodules/Components/BalancedTextComponent",
        "//submodules/TelegramUI/Components/LottieComponent",
        "//submodules/TelegramUI/Components/AlertComponent",
        "//submodules/TelegramUI/Components/ButtonComponent",
        "//submodules/TelegramUI/Components/SegmentControlComponent",
        "//submodules/WalletContext",
        "//submodules/TelegramUI/Components/Wallet/WalletAuthorizationUI",
    ],
    visibility = [
        "//visibility:public",
    ],
)
