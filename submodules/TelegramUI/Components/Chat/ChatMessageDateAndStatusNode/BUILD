load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_unit_test")
load("@build_bazel_rules_apple//apple/testing/default_runner:ios_test_runner.bzl", "ios_test_runner")

swift_library(
    name = "ChatMessageDateAndStatusNode",
    module_name = "ChatMessageDateAndStatusNode",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/AsyncDisplayKit",
        "//submodules/TelegramCore",
        "//submodules/Display",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/TelegramUIPreferences",
        "//submodules/TelegramPresentationData",
        "//submodules/AccountContext",
        "//submodules/AppBundle",
        "//submodules/TelegramStringFormatting",
        "//submodules/TextFormat",
        "//submodules/LocalizedPeerData",
        "//submodules/Components/ReactionButtonListComponent",
        "//submodules/Components/ReactionImageComponent",
        "//submodules/TelegramUI/Components/AnimationCache",
        "//submodules/TelegramUI/Components/MultiAnimationRenderer",
    ],
    visibility = [
        "//visibility:public",
    ],
)

swift_library(
    name = "ChatMessageDateAndStatusNodeTestsLib",
    testonly = True,
    srcs = glob([
        "Tests/**/*.swift",
    ]),
    deps = [
        ":ChatMessageDateAndStatusNode",
    ],
)

# The runner MUST pin a real device/OS: the default runner picks an invalid
# device and the test process exits 15. Matches //submodules/InstantPageUI:InstantPageUITests.
ios_test_runner(
    name = "ChatMessageDateAndStatusNodeTestRunner",
    device_type = "iPhone 17",
    os_version = "26.5",
)

ios_unit_test(
    name = "ChatMessageDateAndStatusNodeTests",
    # AccountContext pulls in LegacyComponents, whose TGMediaPickerGalleryVideoItemView references
    # MPVolumeView. The app target links MediaPlayer implicitly; a standalone test binary does not.
    # Mirrors //submodules/TelegramUI/Components/Chat/ChatRichTextEditorComposer:ChatRichTextEditorComposerTests.
    linkopts = ["-framework", "MediaPlayer"],
    minimum_os_version = "15.0",
    runner = ":ChatMessageDateAndStatusNodeTestRunner",
    deps = [
        ":ChatMessageDateAndStatusNodeTestsLib",
    ],
    visibility = [
        "//visibility:public",
    ],
)
