load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_unit_test")
load("@build_bazel_rules_apple//apple/testing/default_runner:ios_test_runner.bzl", "ios_test_runner")

swift_library(
    name = "LegacyMediaPickerUI",
    module_name = "LegacyMediaPickerUI",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/SSignalKit/SSignalKit",
    	"//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/Display:Display",
        "//submodules/Postbox:Postbox",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/AccountContext:AccountContext",
        "//submodules/LegacyComponents:LegacyComponents",
        "//submodules/LegacyUI:LegacyUI",
        "//submodules/ContextUI:ContextUI",
        "//submodules/MimeTypes:MimeTypes",
        "//submodules/LocalMediaResources:LocalMediaResources",
        "//submodules/SearchPeerMembers:SearchPeerMembers",
        "//submodules/SaveToCameraRoll:SaveToCameraRoll",
        "//submodules/AnimatedStickerNode:AnimatedStickerNode",
        "//submodules/TelegramAnimatedStickerNode:TelegramAnimatedStickerNode",
        "//submodules/StickerResources:StickerResources",
        "//submodules/TextFormat:TextFormat",
        "//submodules/DrawingUI:DrawingUI",
        "//submodules/SolidRoundedButtonNode:SolidRoundedButtonNode",
        "//submodules/TelegramUI/Components/MediaEditor",
        "//submodules/AnimatedCountLabelNode",
    ],
    visibility = [
        "//visibility:public",
    ],
)

swift_library(
    name = "LegacyMediaPickerUITestsLib",
    testonly = True,
    srcs = glob([
        "Tests/**/*.swift",
    ]),
    deps = [
        ":LegacyMediaPickerUI",
    ],
)

# The runner MUST pin a real device/OS: the default runner picks an invalid
# device and the test process exits 15.
ios_test_runner(
    name = "LegacyMediaPickerUITestRunner",
    device_type = "iPhone 17",
    os_version = "26.5",
)

ios_unit_test(
    name = "LegacyMediaPickerUITests",
    minimum_os_version = "15.0",
    runner = ":LegacyMediaPickerUITestRunner",
    deps = [
        ":LegacyMediaPickerUITestsLib",
    ],
    visibility = [
        "//visibility:public",
    ],
)
