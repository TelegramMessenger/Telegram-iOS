load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_unit_test")
load("@build_bazel_rules_apple//apple/testing/default_runner:ios_test_runner.bzl", "ios_test_runner")

# See //submodules/TelegramUI:composer_state_writer_sources.
filegroup(
    name = "composer_state_writer_sources",
    srcs = ["Sources/ChatTextInputPanelNode.swift"],
    visibility = ["//visibility:public"],
)

swift_library(
    name = "ChatTextInputPanelNode",
    module_name = "ChatTextInputPanelNode",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Display",
        "//submodules/LottieSettings:LottieSettings",
        "//submodules/AsyncDisplayKit",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/TelegramCore",
        "//submodules/TelegramPresentationData",
        "//submodules/TextFormat",
        "//submodules/AccountContext",
        "//submodules/TouchDownGesture",
        "//submodules/ImageTransparency",
        "//submodules/ActivityIndicator",
        "//submodules/AnimationUI",
        "//submodules/Speak",
        "//submodules/ObjCRuntimeUtils",
        "//submodules/AvatarNode",
        "//submodules/ContextUI",
        "//submodules/InvisibleInkDustNode",
        "//submodules/TextInputMenu",
        "//submodules/Pasteboard",
        "//submodules/ChatPresentationInterfaceState",
        "//submodules/ManagedAnimationNode",
        "//submodules/TelegramUI/Components/EditableChatTextNode",
        "//submodules/TelegramUI/Components/EmojiTextAttachmentView",
        "//submodules/Components/LottieAnimationComponent",
        "//submodules/ComponentFlow",
        "//submodules/TelegramUI/Components/EmojiSuggestionsComponent",
        "//submodules/TelegramUI/Components/ChatControllerInteraction",
        "//submodules/UndoUI",
        "//submodules/PremiumUI",
        "//submodules/StickerPeekUI",
        "//submodules/TelegramUI/Components/LottieComponent",
        "//submodules/SolidRoundedButtonNode",
        "//submodules/TooltipUI",
        "//submodules/TelegramUI/Components/ChatTextInputMediaRecordingButton",
        "//submodules/ChatContextQuery",
        "//submodules/TelegramUI/Components/Chat/ChatInputTextNode",
        "//submodules/TelegramUI/Components/Chat/ChatRichTextEditorComposer",
        "//submodules/TelegramUI/Components/Chat/ChatInputPanelNode",
        "//submodules/TelegramNotices",
        "//submodules/AnimatedCountLabelNode",
        "//submodules/TelegramStringFormatting",
        "//submodules/TelegramUI/Components/TextNodeWithEntities",
        "//submodules/Utils/DeviceModel",
        "//submodules/PhotoResources",
        "//submodules/TelegramUI/Components/Chat/ChatTextInputSlowmodePlaceholderNode",
        "//submodules/TelegramUI/Components/Chat/ChatTextInputActionButtonsNode",
        "//submodules/TelegramUI/Components/Chat/ChatTextInputAudioRecordingTimeNode",
        "//submodules/TelegramUI/Components/Chat/ChatTextInputAudioRecordingCancelIndicator",
        "//submodules/TelegramUI/Components/Chat/ChatRecordingViewOnceButtonNode",
        "//submodules/TelegramUI/Components/GlassBackgroundComponent",
        "//submodules/TelegramUI/Components/Chat/ChatInputAccessoryPanel",
        "//submodules/TelegramUI/Components/Chat/ChatInputAutocompletePanel",
        "//submodules/TelegramUI/Components/Chat/ChatRecordingPreviewInputPanelNode",
        "//submodules/TelegramUI/Components/Chat/ChatInputContextPanelNode",
        "//submodules/TelegramUI/Components/AnimatedTextComponent",
        "//submodules/TelegramUI/Components/RasterizedCompositionComponent",
        "//submodules/TelegramUI/Components/StarsParticleEffect",
        "//submodules/TelegramUI/Components/Calls/VideoChatMicButtonComponent",
        "//submodules/TelegramUI/Components/RichTextEditor:RichTextEditorUIKit",
        "//submodules/TelegramUI/Components/RichTextEditor:RichTextEditorCore",
    ],
    visibility = [
        "//visibility:public",
    ],
)

swift_library(
    name = "ChatTextInputPanelNodeTestsLib",
    testonly = True,
    srcs = glob([
        "Tests/**/*.swift",
    ]),
    deps = [
        ":ChatTextInputPanelNode",
        "//submodules/TelegramUI/Components/Chat/ChatInputTextNode",
        "//submodules/TextFormat",
        "//submodules/TelegramUIPreferences",
        "//submodules/TelegramPresentationData",
        "//submodules/Display",
    ],
)

# The runner MUST pin a real device/OS: the default runner picks an invalid
# device and the test process exits 15. Matches //submodules/InstantPageUI:InstantPageUITests.
ios_test_runner(
    name = "ChatTextInputPanelNodeTestRunner",
    device_type = "iPhone 17",
    os_version = "26.5",
)

ios_unit_test(
    name = "ChatTextInputPanelNodeTests",
    minimum_os_version = "15.0",
    runner = ":ChatTextInputPanelNodeTestRunner",
    deps = [
        ":ChatTextInputPanelNodeTestsLib",
    ],
    visibility = [
        "//visibility:public",
    ],
)
