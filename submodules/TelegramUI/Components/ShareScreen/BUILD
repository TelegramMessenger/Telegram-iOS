load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_unit_test")
load("@build_bazel_rules_apple//apple/testing/default_runner:ios_test_runner.bzl", "ios_test_runner")

swift_library(
    name = "ShareScreen",
    module_name = "ShareScreen",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/AsyncDisplayKit",
        "//submodules/ContextUI",
        "//submodules/TelegramUI/Components/AuthConfirmationScreen",
        "//submodules/TelegramUI/Components/PeerInfo/AccountPeerContextItem",
        "//submodules/Display",
        "//submodules/TelegramCore",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/ComponentFlow",
        "//submodules/Components/ViewControllerComponent",
        "//submodules/Components/ComponentDisplayAdapters",
        "//submodules/Components/MultilineTextComponent",
        "//submodules/Components/BalancedTextComponent",
        "//submodules/TelegramPresentationData",
        "//submodules/AccountContext",
        "//submodules/AppBundle",
        "//submodules/ItemListUI",
        "//submodules/TelegramStringFormatting",
        "//submodules/PresentationDataUtils",
        "//submodules/ShareController",
        "//submodules/SaveToCameraRoll",
        "//submodules/ChatListUI",
        "//submodules/AvatarNode",
        "//submodules/CheckNode",
        "//submodules/TelegramUI/Components/EmojiStatusComponent",
        "//submodules/ChatPresentationInterfaceState",
        "//submodules/TelegramUI/Components/ChatEntityKeyboardInputNode",
        "//submodules/TelegramUI/Components/Stories/PeerListItemComponent",
        "//submodules/TelegramUI/Components/Chat/ChatMessagePaymentAlertController",
        "//submodules/Components/SheetComponent",
        "//submodules/UndoUI",
        "//submodules/TextFormat",
        "//submodules/TelegramUI/Components/ButtonComponent",
        "//submodules/TelegramUI/Components/AnimatedTextComponent",
        "//submodules/TelegramUI/Components/HorizontalTabsComponent",
        "//submodules/TelegramUI/Components/NavigationStackComponent",
        "//submodules/Components/BundleIconComponent",
        "//submodules/TelegramUI/Components/GlassBackgroundComponent",
        "//submodules/TelegramUI/Components/GlassBarButtonComponent",
        "//submodules/TelegramUI/Components/EdgeEffect",
        "//submodules/TelegramUI/Components/PlainButtonComponent",
        "//submodules/Components/ResizableSheetComponent",
        "//submodules/TelegramUI/Components/MessageInputPanelComponent",
        "//submodules/TelegramUI/Components/Chat/MergedAvatarsNode",
        "//submodules/TooltipUI",
        "//submodules/TelegramNotices",
        "//submodules/TelegramUI/Components/LottieComponent",
        "//submodules/LottieSettings",
        "//submodules/TelegramUI/Components/SegmentControlComponent",
        "//submodules/UIKitRuntimeUtils",
    ],
    visibility = [
        "//visibility:public",
    ],
)

swift_library(
    name = "ShareScreenTestsLib",
    testonly = True,
    srcs = glob(["Tests/*.swift"]),
    deps = [
        ":ShareScreen",
        "//submodules/TelegramCore",
    ],
)

ios_test_runner(
    name = "ShareScreenTestRunner",
    device_type = "iPhone 17",
    os_version = "26.5",
)

ios_unit_test(
    name = "ShareScreenTests",
    runner = ":ShareScreenTestRunner",
    minimum_os_version = "15.0",
    deps = [":ShareScreenTestsLib"],
)
