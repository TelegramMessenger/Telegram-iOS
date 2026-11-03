load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load("@build_bazel_rules_apple//apple:resources.bzl", "apple_resource_bundle")
load("//build-system/bazel-utils:plist_fragment.bzl", "plist_fragment")

plist_fragment(
    name = "WalletSendAmountMetalSourcesBundleInfoPlist",
    extension = "plist",
    template = """
    <key>CFBundleIdentifier</key>
    <string>org.telegram.WalletSendAmountMetalSources</string>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleName</key>
    <string>WalletSendAmount</string>
    """,
)

apple_resource_bundle(
    name = "WalletSendAmountMetalSourcesBundle",
    infoplists = [":WalletSendAmountMetalSourcesBundleInfoPlist"],
    resources = glob(["Resources/*.metal"]),
)

swift_library(
    name = "WalletSendScreen",
    module_name = "WalletSendScreen",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    data = [":WalletSendAmountMetalSourcesBundle"],
    deps = [
        "//submodules/AccountContext",
        "//submodules/AppBundle",
        "//submodules/AttachmentUI",
        "//submodules/ComponentFlow",
        "//submodules/TelegramUI/Components/Wallet/WalletSendKeyboardComponent",
        "//submodules/Components/BundleIconComponent",
        "//submodules/Components/MultilineTextComponent",
        "//submodules/Components/ViewControllerComponent",
        "//submodules/ContextUI",
        "//submodules/Display",
        "//submodules/MetalEngine",
        "//submodules/LocalizedPeerData:LocalizedPeerData",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/TelegramCore",
        "//submodules/TelegramPresentationData",
        "//submodules/PresentationDataUtils",
        "//submodules/TelegramStringFormatting",
        "//submodules/TelegramUIPreferences",
        "//submodules/TelegramUI/Components/AnimatedTextComponent",
        "//submodules/TelegramUI/Components/AvatarComponent",
        "//submodules/TelegramUI/Components/AlertComponent",
        "//submodules/TelegramUI/Components/AlertComponent/AlertCheckComponent",
        "//submodules/TelegramUI/Components/AlertComponent/AlertMultilineInputFieldComponent",
        "//submodules/TelegramUI/Components/ButtonComponent",
        "//submodules/TelegramUI/Components/GlassBackgroundComponent",
        "//submodules/TelegramUI/Components/GlassControls",
        "//submodules/TelegramUI/Components/PlainButtonComponent",
        "//submodules/TelegramUI/Components/Premium/PremiumDiamondComponent",
        "//submodules/TelegramUI/Components/ShimmeringMask",
        "//submodules/QrCodeUI",
        "//submodules/WalletContext",
        "//submodules/PasscodeCore",
        "//submodules/TelegramUI/Components/Wallet/WalletAuthorizationUI",
        "//submodules/UndoUI",
    ],
    visibility = [
        "//visibility:public",
    ],
)
