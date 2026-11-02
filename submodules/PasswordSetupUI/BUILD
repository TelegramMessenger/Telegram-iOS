load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_unit_test")
load("@build_bazel_rules_apple//apple/testing/default_runner:ios_test_runner.bzl", "ios_test_runner")

filegroup(
    name = "PasswordSetupUIResources",
    srcs = glob([
        "Resources/**/*",
    ], exclude = ["Resources/**/.*"]),
    visibility = ["//visibility:public"],
)

filegroup(
    name = "PasswordSetupUIAssets",
    srcs = glob(["PasswordSetupUIImages.xcassets/**"]),
    visibility = ["//visibility:public"],
)

swift_library(
    name = "PasswordSetupUI",
    module_name = "PasswordSetupUI",
    srcs = glob([
		"Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/Display:Display",
        "//submodules/ComponentFlow:ComponentFlow",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/AccountContext:AccountContext",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/ProgressNavigationButtonNode:ProgressNavigationButtonNode",
        "//submodules/ActivityIndicator:ActivityIndicator",
        "//submodules/AlertUI:AlertUI",
        "//submodules/PresentationDataUtils:PresentationDataUtils",
        "//submodules/ItemListUI:ItemListUI",
        "//submodules/AnimatedStickerNode:AnimatedStickerNode",
        "//submodules/TelegramAnimatedStickerNode:TelegramAnimatedStickerNode",
        "//submodules/TelegramUI/Components/ButtonComponent",
        "//submodules/AppBundle:AppBundle",
        "//submodules/OverlayStatusController:OverlayStatusController",
        "//submodules/LottieBinding:LottieBinding",
        "//submodules/ManagedAnimationNode:ManagedAnimationNode",
        "//submodules/AuthorizationUtils:AuthorizationUtils",
    ],
    visibility = [
        "//visibility:public",
    ],
)

swift_library(
    name = "PasswordSetupUITestsLib",
    testonly = True,
    srcs = glob([
        "Tests/**/*.swift",
    ]),
    deps = [
        ":PasswordSetupUI",
        "//submodules/Display:Display",
    ],
)

# The runner MUST pin a real device/OS: the default runner picks an invalid
# device and the test process exits 15.
ios_test_runner(
    name = "PasswordSetupUITestRunner",
    device_type = "iPhone 17",
    os_version = "26.5",
)

ios_unit_test(
    name = "PasswordSetupUITests",
    minimum_os_version = "15.0",
    runner = ":PasswordSetupUITestRunner",
    deps = [
        ":PasswordSetupUITestsLib",
    ],
    visibility = [
        "//visibility:public",
    ],
)
