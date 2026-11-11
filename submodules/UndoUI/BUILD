load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_unit_test")
load("@build_bazel_rules_apple//apple/testing/default_runner:ios_test_runner.bzl", "ios_test_runner")

swift_library(
    name = "UndoUI",
    module_name = "UndoUI",
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
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/TextFormat:TextFormat",
        "//submodules/Markdown:Markdown",
        "//submodules/RadialStatusNode:RadialStatusNode",
        "//submodules/AnimationUI:AnimationUI",
        "//submodules/AnimatedStickerNode:AnimatedStickerNode",
        "//submodules/AppBundle:AppBundle",
        "//submodules/StickerResources:StickerResources",
        "//submodules/TelegramAnimatedStickerNode:TelegramAnimatedStickerNode",
        "//submodules/SlotMachineAnimationNode:SlotMachineAnimationNode",
        "//submodules/AvatarNode:AvatarNode",
        "//submodules/AccountContext:AccountContext",
        "//submodules/ComponentFlow:ComponentFlow",
        "//submodules/AnimatedAvatarSetNode:AnimatedAvatarSetNode",
        "//submodules/TelegramUI/Components/EmojiStatusComponent",
        "//submodules/TelegramUI/Components/TextNodeWithEntities",
        "//submodules/Components/BundleIconComponent",
        "//submodules/TelegramUI/Components/AnimatedTextComponent",
        "//submodules/Components/ComponentDisplayAdapters",
        "//submodules/PhotoResources",
    ],
    visibility = [
        "//visibility:public",
    ],
)

swift_library(
    name = "UndoUITestsLib",
    testonly = True,
    srcs = glob([
        "Tests/**/*.swift",
    ]),
    deps = [
        ":UndoUI",
        "//submodules/Display:Display",
    ],
)

# The runner MUST pin a real device/OS: the default runner picks an invalid
# device and the test process exits 15.
ios_test_runner(
    name = "UndoUITestRunner",
    device_type = "iPhone 17",
    os_version = "26.5",
)

ios_unit_test(
    name = "UndoUITests",
    minimum_os_version = "15.0",
    runner = ":UndoUITestRunner",
    deps = [
        ":UndoUITestsLib",
    ],
    visibility = [
        "//visibility:public",
    ],
)
