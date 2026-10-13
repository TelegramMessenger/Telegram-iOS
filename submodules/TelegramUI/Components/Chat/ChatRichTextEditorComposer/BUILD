load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_unit_test")
load("@build_bazel_rules_apple//apple/testing/default_runner:ios_test_runner.bzl", "ios_test_runner")

swift_library(
    name = "ChatRichTextEditorComposer",
    module_name = "ChatRichTextEditorComposer",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/AppBundle",
        "//submodules/AsyncDisplayKit",
        "//submodules/ContextUI",
        "//submodules/Display",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/TelegramUI/Components/RichTextEditorMessageConversion",
        "//submodules/TelegramPresentationData",
        "//submodules/TextFormat",
        "//submodules/TelegramUI/Components/RichTextEditor:RichTextEditorCore",
        "//submodules/TelegramUI/Components/RichTextEditor:RichTextEditorUIKit",
        "//submodules/TelegramUI/Components/RichTextButtonIcons",
        "//submodules/TelegramUI/Components/Chat/ChatInputTextNode",
        "//submodules/TelegramUI/Components/PlainButtonComponent",
        "//submodules/Components/BundleIconComponent",
        "//submodules/Components/MultilineTextComponent",
        "//submodules/CheckNode",
        "//submodules/Pasteboard",
    ],
    visibility = [
        "//visibility:public",
    ],
)

swift_library(
    name = "ChatRichTextEditorComposerTestsLib",
    testonly = True,
    srcs = glob([
        "Tests/**/*.swift",
    ]),
    deps = [
        ":ChatRichTextEditorComposer",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/Postbox:Postbox",
        # ChatTextInputStateReplaceRangeTests exercises ChatTextInputState (AccountContext) through the
        # chat attribute vocabulary (TextFormat). This is the one small target that can import both.
        "//submodules/AccountContext",
        "//submodules/TextFormat",
        "//submodules/TelegramUI/Components/RichTextEditor:RichTextEditorCore",
        "//submodules/TelegramUI/Components/RichTextEditorMessageConversion",
    ],
    # Read at runtime by ComposerFlatRebuildGuardTests, which scans them for the flat-rebuild
    # anti-pattern. A sandboxed XCTest sees only declared files, hence `data` rather than a glob.
    data = [
        "//submodules/TelegramUI:composer_state_writer_sources",
        "//submodules/TelegramUI/Components/Chat/ChatTextInputPanelNode:composer_state_writer_sources",
    ],
)

# The default ios_test_runner picks an invalid device and the test process exits 15 — pin it to a
# real device/OS, mirroring //submodules/TextFormat:TextFormatTestRunner. See CLAUDE.md.
ios_test_runner(
    name = "ChatRichTextEditorComposerTestRunner",
    device_type = "iPhone 17",
    os_version = "26.5",
)

ios_unit_test(
    name = "ChatRichTextEditorComposerTests",
    # ContextUI pulls in LegacyComponents, whose TGMediaPickerGalleryVideoItemView references
    # MPVolumeView. The app target links MediaPlayer implicitly; a standalone test binary does not.
    linkopts = ["-framework", "MediaPlayer"],
    minimum_os_version = "15.0",
    runner = ":ChatRichTextEditorComposerTestRunner",
    deps = [
        ":ChatRichTextEditorComposerTestsLib",
    ],
    visibility = [
        "//visibility:public",
    ],
)
