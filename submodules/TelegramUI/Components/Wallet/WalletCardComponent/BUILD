load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

load(
    "@build_bazel_rules_apple//apple:resources.bzl",
    "apple_resource_bundle",
)
load(
    "//build-system/bazel-utils:plist_fragment.bzl",
    "plist_fragment",
)

filegroup(
    name = "WalletCardComponentMetalSources",
    srcs = glob([
        "Resources/**/*.metal",
    ]),
    visibility = ["//visibility:public"],
)

plist_fragment(
    name = "WalletCardComponentMetalSourcesBundleInfoPlist",
    extension = "plist",
    template =
    """
    <key>CFBundleIdentifier</key>
    <string>org.telegram.WalletCardComponentMetalSources</string>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleName</key>
    <string>WalletCardComponent</string>
    """
)

apple_resource_bundle(
    name = "WalletCardComponentMetalSourcesBundle",
    infoplists = [
        ":WalletCardComponentMetalSourcesBundleInfoPlist",
    ],
    resources = [
        ":WalletCardComponentMetalSources",
    ],
)

swift_library(
    name = "WalletCardComponent",
    module_name = "WalletCardComponent",
    srcs = glob(
        ["Sources/**/*.swift"],
        exclude = ["Sources/ref/**/*.swift"],
    ),
    copts = [
        "-warnings-as-errors",
    ],
    data = [
        ":WalletCardComponentMetalSourcesBundle",
    ],
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/Display",
        "//submodules/MetalEngine",
        "//submodules/ComponentFlow",
        "//submodules/TelegramUI/Components/AnimatedTextComponent",
        "//submodules/TelegramUI/Components/PlainButtonComponent",
        "//submodules/TelegramUI/Components/Premium/PremiumDiamondComponent",
        "//submodules/Components/BundleIconComponent",
        "//submodules/Components/MultilineTextComponent",
        "//submodules/TelegramPresentationData",
        "//submodules/TelegramStringFormatting",
        "//submodules/WalletContext",
    ],
    visibility = [
        "//visibility:public",
    ],
)
