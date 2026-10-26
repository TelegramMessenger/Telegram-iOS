load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_unit_test")
load("@build_bazel_rules_apple//apple/testing/default_runner:ios_test_runner.bzl", "ios_test_runner")

# Packages allowed to depend on Postbox. This list only shrinks: when a refactor wave frees a
# package, remove it here in the same commit (CLAUDE.md, "Postbox -> TelegramEngine refactor").
package_group(
    name = "clients",
    packages = [
        "//Telegram",
        "//Telegram/NotificationService",
        "//submodules/AccountContext",
        "//submodules/AvatarNode",
        "//submodules/ChatListUI",
        "//submodules/ChatPresentationInterfaceState",
        "//submodules/DirectMediaImageCache",
        "//submodules/FeaturedStickersScreen",
        "//submodules/FetchManagerImpl",
        "//submodules/GalleryUI",
        "//submodules/LegacyMediaPickerUI",
        "//submodules/MediaPlayer",
        "//submodules/PassportUI",
        "//submodules/PhotoResources",
        "//submodules/PremiumUI",
        "//submodules/ShareController",
        "//submodules/ShareItems",
        "//submodules/StatisticsUI",
        "//submodules/StickerResources",
        "//submodules/TelegramAnimatedStickerNode",
        "//submodules/TelegramCallsUI",
        "//submodules/TelegramCore",
        "//submodules/TelegramPermissionsUI",
        "//submodules/TelegramPresentationData",
        "//submodules/TelegramUI",
        "//submodules/TelegramUI/Components/Chat/ChatMessageBubbleItemNode",
        "//submodules/TelegramUI/Components/Chat/ChatRecentActionsController",
        "//submodules/TelegramUI/Components/ChatEntityKeyboardInputNode",
        "//submodules/TelegramUI/Components/DebugCompanionScreen",
        "//submodules/TelegramUI/Components/EmojiStatusComponent",
        "//submodules/TelegramUI/Components/EmojiTextAttachmentView",
        "//submodules/TelegramUI/Components/EntityKeyboard",
        "//submodules/TelegramUI/Components/MediaEditor",
        "//submodules/TelegramUI/Components/MediaEditorScreen",
        "//submodules/TelegramUI/Components/Resources/FetchVideoMediaResource",
        "//submodules/TelegramUI/Components/StickerPickerScreen",
        "//submodules/TelegramUI/Components/Stories/StoryContainerScreen",
        "//submodules/TelegramUI/Components/TelegramAccountAuxiliaryMethods",
        "//submodules/TelegramUniversalVideoContent",
        "//submodules/TemporaryCachedPeerDataManager",
    ],
)

# Packages whose remaining Postbox dependency is test targets only.
package_group(
    name = "test_clients",
    packages = [
        "//Tests/ComposerHarness",
        "//submodules/TelegramStringFormatting",
        "//submodules/TelegramUI/Components/Chat/ChatMessageItemCommon",
        "//submodules/TelegramUI/Components/Chat/ChatRichTextEditorComposer",
        "//submodules/TelegramUI/Components/Chat/EditableTokenListNode",
        "//submodules/TelegramUI/Components/PeerInfo/PeerInfoPaneNode",
        "//submodules/TelegramUI/Components/RichTextEditorMessageConversion",
        "//submodules/TextFormat",
    ],
)

swift_library(
    name = "Postbox",
    module_name = "Postbox",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/Crc32:Crc32",
    	"//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
    	"//submodules/sqlcipher:sqlcipher",
        "//submodules/MurMurHash32:MurMurHash32",
        "//submodules/StringTransliteration:StringTransliteration",
        "//submodules/ManagedFile:ManagedFile",
        "//submodules/Utils/RangeSet:RangeSet",
        "//submodules/CryptoUtils",
        "//submodules/Utils/DarwinDirStat",
    ],
    visibility = [
        ":clients",
        ":test_clients",
    ],
)

swift_library(
    name = "PostboxTestsLib",
    testonly = True,
    srcs = glob([
        "Tests/**/*.swift",
    ]),
    deps = [
        ":Postbox",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/sqlcipher:sqlcipher",
    ],
)

ios_test_runner(
    name = "PostboxTestRunner",
    device_type = "iPhone 17",
    os_version = "26.5",
)

ios_unit_test(
    name = "PostboxTests",
    minimum_os_version = "15.0",
    runner = ":PostboxTestRunner",
    deps = [
        ":PostboxTestsLib",
    ],
    visibility = [
        "//visibility:public",
    ],
)
