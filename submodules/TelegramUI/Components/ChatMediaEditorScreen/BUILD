load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_unit_test")
load("@build_bazel_rules_apple//apple/testing/default_runner:ios_test_runner.bzl", "ios_test_runner")

swift_library(
    name = "ChatMediaEditorScreen",
    module_name = "ChatMediaEditorScreen",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/TelegramCore",
        "//submodules/AccountContext",
        "//submodules/TelegramUI/Components/MediaEditor",
        "//submodules/LegacyMediaPickerUI",
        "//submodules/LegacyComponents",
        "//submodules/TextFormat",
        "//submodules/ImageCompression",
        "//submodules/LocalMediaResources",
        "//submodules/TelegramUIPreferences",
        "//submodules/Display",
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/ComponentFlow:ComponentFlow",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/DrawingUI:DrawingUI",
        "//submodules/MediaPickerUI:MediaPickerUI",
        "//submodules/TelegramUI/Components/MediaEditorScreen",
        "//submodules/TelegramUI/Components/MediaScrubberComponent",
        "//submodules/SaveToCameraRoll:SaveToCameraRoll",
        "//submodules/LocalizedPeerData:LocalizedPeerData",
        "//submodules/TelegramUI/Components/MediaCropComponent",
        "//submodules/ContextUI:ContextUI",
        "//submodules/TelegramUI/Components/ChatMediaSend",
        "//submodules/PresentationDataUtils:PresentationDataUtils",
        "//submodules/RadialStatusNode:RadialStatusNode",
        "//submodules/TelegramUI/Components/MediaAssetsContext",
        "//submodules/TooltipUI:TooltipUI",
        "//submodules/TelegramUI/Components/SliderComponent",
        "//submodules/TelegramUI/Components/GlassBackgroundComponent",
        "//submodules/TelegramUI/Components/PlainButtonComponent",
        "//submodules/Components/BundleIconComponent",
        "//submodules/TelegramUI/Components/MediaEditorBottomControls",
    ],
    visibility = [
        "//visibility:public",
    ],
)

swift_library(
    name = "ChatMediaEditorScreenTestsLib",
    testonly = True,
    srcs = glob([
        "Tests/**/*.swift",
    ]),
    deps = [
        ":ChatMediaEditorScreen",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/AccountContext",
        "//submodules/TelegramCore",
        "//submodules/TelegramUI/Components/MediaEditor",
        "//submodules/TextFormat",
        "//submodules/Display",
        "//submodules/LegacyMediaPickerUI",
        "//submodules/LocalMediaResources",
        "//submodules/LegacyComponents",
        "//submodules/TelegramUI/Components/MediaCropComponent",
        "//submodules/TelegramUI/Components/MediaEditorScreen",
        "//submodules/TelegramUI/Components/ChatMediaSend",
        "//submodules/ComponentFlow:ComponentFlow",
        "//submodules/DrawingUI:DrawingUI",
    ],
)

ios_test_runner(
    name = "ChatMediaEditorScreenTestRunner",
    device_type = "iPhone 17",
    os_version = "26.5",
)

ios_unit_test(
    name = "ChatMediaEditorScreenTests",
    minimum_os_version = "15.0",
    runner = ":ChatMediaEditorScreenTestRunner",
    deps = [
        ":ChatMediaEditorScreenTestsLib",
    ],
    visibility = [
        "//visibility:public",
    ],
)
