load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

filegroup(
    name = "PasswordSetupUIResources",
    srcs = glob([
        "Resources/**/*",
    ], exclude = ["Resources/**/.*"]),
)

filegroup(
    name = "PasswordSetupUIAssets",
    srcs = glob(["PasswordSetupUIImages.xcassets/**"]),
)

swift_library(
    name = "PasswordSetupUI",
    module_name = "PasswordSetupUI",
    srcs = glob([
		"Sources/**/*.swift",
    ]),
    data = [
        ":PasswordSetupUIResources",
        ":PasswordSetupUIAssets",
    ],
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/Display:Display",
        "//submodules/Postbox:Postbox",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/SyncCore:SyncCore",
        "//submodules/AccountContext:AccountContext",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/ProgressNavigationButtonNode:ProgressNavigationButtonNode",
        "//submodules/ActivityIndicator:ActivityIndicator",
        "//submodules/AlertUI:AlertUI",
        "//submodules/PresentationDataUtils:PresentationDataUtils",
        "//submodules/ItemListUI:ItemListUI",
        "//submodules/AnimatedStickerNode:AnimatedStickerNode",
        "//submodules/AppBundle:AppBundle",
        "//submodules/SolidRoundedButtonNode:SolidRoundedButtonNode",
        "//submodules/OverlayStatusController:OverlayStatusController",
        "//submodules/rlottie:RLottieBinding",
    ],
    visibility = [
        "//visibility:public",
    ],
)
