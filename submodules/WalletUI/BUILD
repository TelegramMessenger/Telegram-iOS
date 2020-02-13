load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

'''apple_resource(
    name = "WalletUIResources",
    files = glob([
        "Resources/**/*",
    ], exclude = ["Resources/**/.*"]),
    visibility = ["PUBLIC"],
)'''

'''apple_asset_catalog(
    name = 'WalletUIAssets',
    dirs = [
        "WalletImages.xcassets",
    ],
    visibility = ["PUBLIC"],
)'''

filegroup(
    name = "WalletUIResources",
    srcs = glob([
        "Resources/**/*",
    ], exclude = ["Resources/**/.*"]),
)

filegroup(
    name = "WalletUIAssets",
    srcs = glob(["WalletImages.xcassets/**"]),
)

swift_library(
    name = "WalletUI",
    module_name = "WalletUI",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    data = [
        ":WalletUIResources",
        ":WalletUIAssets",
    ],
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/Display:Display",
        "//submodules/OverlayStatusController:OverlayStatusController",
        "//submodules/AppBundle:AppBundle",
        "//submodules/SolidRoundedButtonNode:SolidRoundedButtonNode",
        "//submodules/AlertUI:AlertUI",
        "//submodules/Camera:Camera",
        "//submodules/QrCode:QrCode",
        "//submodules/MergeLists:MergeLists",
        "//submodules/GlassButtonNode:GlassButtonNode",
        "//submodules/UrlEscaping:UrlEscaping",
        "//submodules/LocalAuth:LocalAuth",
        "//submodules/ScreenCaptureDetection:ScreenCaptureDetection",
        "//submodules/WalletUrl:WalletUrl",
        "//submodules/WalletCore:WalletCore",
        "//submodules/ActivityIndicator:ActivityIndicator",
        "//submodules/ProgressNavigationButtonNode:ProgressNavigationButtonNode",
        "//submodules/Markdown:Markdown",
        "//submodules/StringPluralization:StringPluralization",
        "//submodules/AnimatedStickerNode:AnimatedStickerNode",
    ],
    visibility = [
        "//visibility:public",
    ],
)
