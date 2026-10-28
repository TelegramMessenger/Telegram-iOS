load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_unit_test")
load("@build_bazel_rules_apple//apple/testing/default_runner:ios_test_runner.bzl", "ios_test_runner")

swift_library(
    name = "VideoMessageCameraScreen",
    module_name = "VideoMessageCameraScreen",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/AsyncDisplayKit",
        "//submodules/Display",
        "//submodules/TelegramCore",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/ComponentFlow",
        "//submodules/Components/ViewControllerComponent",
        "//submodules/Components/ComponentDisplayAdapters",
        "//submodules/TelegramPresentationData",
        "//submodules/AccountContext",
        "//submodules/AppBundle",
        "//submodules/TelegramStringFormatting",
        "//submodules/PresentationDataUtils",
        "//submodules/MediaResources",
        "//submodules/LocalMediaResources",
        "//submodules/ImageCompression",
        "//submodules/Camera",
        "//submodules/Camera/CameraLegacy",
        "//submodules/Camera/CameraNeo",
        "//submodules/Components/MultilineTextComponent",
        "//submodules/Components/BlurredBackgroundComponent",
        "//submodules/Components/BundleIconComponent:BundleIconComponent",
        "//submodules/TelegramUI/Components/ButtonComponent",
        "//submodules/TelegramUI/Components/PlainButtonComponent",
        "//submodules/TelegramUI/Components/CameraButtonComponent",
        "//submodules/TooltipUI",
        "//submodules/TelegramNotices",
        "//submodules/DeviceAccess",
        "//submodules/TelegramUI/Components/MediaEditor",
        "//submodules/LegacyMediaPickerUI",
        "//submodules/TelegramAudio",
        "//submodules/ChatSendMessageActionUI",
        "//submodules/TelegramUI/Components/ChatControllerInteraction",
        "//submodules/TelegramUI/Components/LottieComponent",
        "//submodules/TelegramUI/Components/GlassBackgroundComponent",
    ],
    visibility = [
        "//visibility:public",
    ],
)

swift_library(
    name = "VideoMessageCameraScreenTestsLib",
    testonly = True,
    srcs = glob([
        "Tests/**/*.swift",
    ]),
    deps = [
        ":VideoMessageCameraScreen",
        "//submodules/Display",
    ],
)

ios_test_runner(
    name = "VideoMessageCameraScreenTestRunner",
    device_type = "iPhone 17",
    os_version = "26.5",
)

ios_unit_test(
    name = "VideoMessageCameraScreenTests",
    minimum_os_version = "15.0",
    runner = ":VideoMessageCameraScreenTestRunner",
    deps = [
        ":VideoMessageCameraScreenTestsLib",
    ],
    visibility = [
        "//visibility:public",
    ],
)
