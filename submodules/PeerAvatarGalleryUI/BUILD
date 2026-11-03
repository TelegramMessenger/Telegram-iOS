load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_unit_test")
load("@build_bazel_rules_apple//apple/testing/default_runner:ios_test_runner.bzl", "ios_test_runner")

swift_library(
    name = "PeerAvatarGalleryUI",
    module_name = "PeerAvatarGalleryUI",
    srcs = glob([
		"Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/ComponentFlow",
        "//submodules/ContextUI:ContextUI",
        "//submodules/Display:Display",
        "//submodules/TelegramCore:TelegramCore",
    	"//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/AccountContext:AccountContext",
        "//submodules/GalleryUI:GalleryUI",
        "//submodules/TelegramUIPreferences:TelegramUIPreferences",
        "//submodules/TelegramStringFormatting:TelegramStringFormatting",
        "//submodules/PhotoResources:PhotoResources",
        "//submodules/RadialStatusNode:RadialStatusNode",
        "//submodules/ShareController:ShareController",
        "//submodules/TelegramUI/Components/GlassControls",
        "//submodules/AppBundle:AppBundle",
        "//submodules/LegacyComponents:LegacyComponents",
        "//submodules/LegacyMediaPickerUI:LegacyMediaPickerUI",
        "//submodules/SaveToCameraRoll:SaveToCameraRoll",
        "//submodules/UndoUI:UndoUI",
    ],
    visibility = [
        "//visibility:public",
    ],
)

swift_library(
    name = "PeerAvatarGalleryUITestsLib",
    testonly = True,
    srcs = glob([
        "Tests/**/*.swift",
    ]),
    deps = [
        ":PeerAvatarGalleryUI",
        "//submodules/TelegramCore:TelegramCore",
    ],
)

# The runner MUST pin a real device/OS: the default runner picks an invalid
# device and the test process exits 15.
ios_test_runner(
    name = "PeerAvatarGalleryUITestRunner",
    device_type = "iPhone 17",
    os_version = "26.5",
)

ios_unit_test(
    name = "PeerAvatarGalleryUITests",
    minimum_os_version = "15.0",
    runner = ":PeerAvatarGalleryUITestRunner",
    deps = [
        ":PeerAvatarGalleryUITestsLib",
    ],
    visibility = [
        "//visibility:public",
    ],
)
