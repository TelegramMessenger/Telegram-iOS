load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_application", "ios_ui_test", "ios_unit_test")
load("//build-system/bazel-utils:plist_fragment.bzl", "plist_fragment")
load("@build_bazel_rules_apple//apple/testing/default_runner:ios_test_runner.bzl", "ios_test_runner")
load("@rules_shell//shell:sh_binary.bzl", "sh_binary")

# Pinned to a device/OS that actually exists. The default runner picks an invalid device and the
# test process exits 15 with no diagnostic. Mirrors //submodules/TextFormat:TextFormatTestRunner.
# Runs before every harness test: the reused test simulator would otherwise keep the previous build.
sh_binary(
    name = "UninstallHarnessFromTestSims",
    srcs = ["Tools/uninstall_harness_from_test_sims.sh"],
)

ios_test_runner(
    name = "HarnessTestRunner",
    pre_action = ":UninstallHarnessFromTestSims",
    device_type = "iPhone 17",
    os_version = "26.5",
)

# Tier 2 runs on the OS the harness is hand-driven on (K1 is iPhone 18 Pro / iOS 27.0), so a
# touch-path defect seen there is reproduced on the same UIKit. Tier 1 stays on 26.5 above.
ios_test_runner(
    name = "HarnessUITestRunner",
    pre_action = ":UninstallHarnessFromTestSims",
    device_type = "iPhone 18 Pro",
    os_version = "27.0",
)

swift_library(
    name = "HarnessAppContext",
    module_name = "HarnessAppContext",
    srcs = glob(["AppContext/**/*.swift"]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/Postbox",
        "//submodules/TelegramCore",
        # setupAccountManager lives here, not in TelegramCore.
        "//submodules/PasscodeCore",
        "//submodules/OpenSSLEncryptionProvider",
        "//submodules/AccountContext",
        "//submodules/TelegramPresentationData",
        "//submodules/TelegramUIPreferences",
        "//submodules/Display",
        # The generated stubs name every type AccountContext's own protocols mention, so this
        # target needs what //submodules/AccountContext itself deps on.
        "//submodules/AsyncDisplayKit",
        "//submodules/DeviceLocationManager",
        "//submodules/TemporaryCachedPeerDataManager",
        "//submodules/InAppPurchaseManager",
        "//submodules/TelegramUI/Components/AnimationCache",
        "//submodules/TelegramUI/Components/MultiAnimationRenderer",
        "//submodules/TelegramUI/Components/DCTAnimationCacheImpl",
        "//submodules/TelegramUI/Components/DCTMultiAnimationRendererImpl",
        "//submodules/TextFormat",
        "//submodules/WalletContext",
        "//submodules/LottieSettings",
        "//submodules/TelegramAudio",
        "//submodules/MediaPlayer:UniversalMediaPlayer",
        "//submodules/MusicAlbumArtResources",
        "//submodules/Utils/RangeSet",
    ],
    visibility = ["//Tests:__subpackages__"],
)

swift_library(
    name = "HarnessAppContextTestsLib",
    testonly = True,
    srcs = glob(["AppContextTests/**/*.swift"]),
    deps = [
        ":HarnessAppContext",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/Postbox",
        "//submodules/TelegramCore",
        "//submodules/AccountContext",
    ],
)

ios_unit_test(
    name = "HarnessAppContextTests",
    # Reuse ONE named simulator per device/OS ("BAZEL_TEST_<device>_<os>"). Without it the runner asks
    # xctestrunner for a fresh "New-<device>-<os>" simulator per run, and those were left BOOTED —
    # 23 of them after one session, slowing the machine (2026-09-23).
    env = {"REUSE_GLOBAL_SIMULATOR": "1"},
    # ContextUI pulls LegacyComponents, whose TGMediaPickerGalleryVideoItemView references
    # MPVolumeView. The app target links MediaPlayer implicitly; a standalone test binary does not.
    linkopts = ["-framework", "MediaPlayer"],
    minimum_os_version = "15.0",
    runner = ":HarnessTestRunner",
    deps = [":HarnessAppContextTestsLib"],
    visibility = ["//Tests:__subpackages__"],
)

plist_fragment(
    name = "HarnessInfoPlist",
    extension = "plist",
    template = """
    <key>CFBundleIdentifier</key>
    <string>org.telegram.ComposerHarness</string>
    <key>CFBundleName</key>
    <string>ComposerHarness</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>UILaunchScreen</key>
    <dict/>
    <key>UISupportedInterfaceOrientations</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
        <string>UIInterfaceOrientationLandscapeLeft</string>
        <string>UIInterfaceOrientationLandscapeRight</string>
    </array>
    <key>UIApplicationSceneManifest</key>
    <dict>
        <key>UIApplicationSupportsMultipleScenes</key>
        <false/>
        <key>UISceneConfigurations</key>
        <dict>
            <key>UIWindowSceneSessionRoleApplication</key>
            <array>
                <dict>
                    <key>UISceneConfigurationName</key>
                    <string>Default</string>
                    <key>UISceneDelegateClassName</key>
                    <string>SceneDelegate</string>
                </dict>
            </array>
        </dict>
    </dict>
    """
)

swift_library(
    name = "ComposerHarnessLib",
    module_name = "ComposerHarnessLib",
    srcs = glob(["Sources/**/*.swift"]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        ":HarnessAppContext",
        "//submodules/AsyncDisplayKit",
        "//submodules/Display",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/Postbox",
        "//submodules/TelegramCore",
        "//submodules/TelegramPresentationData",
        "//submodules/AccountContext",
        "//submodules/ChatPresentationInterfaceState",
        "//submodules/TelegramUI/Components/Chat/ChatTextInputPanelNode",
        "//submodules/TelegramUI/Components/Chat/ChatRichTextEditorComposer",
        "//submodules/TelegramUI/Components/Chat/ChatInputTextNode",
        "//submodules/TextFormat",
        "//submodules/TelegramUIPreferences",
        # `inputRichTextAttributeFromText`, the markdown parser behind the panel's pastedMarkdownParser.
        "//submodules/BrowserUI",
    ],
    visibility = ["//Tests:__subpackages__"],
)

ios_application(
    name = "ComposerHarness",
    bundle_id = "org.telegram.ComposerHarness",
    families = ["iphone"],
    # ContextUI pulls LegacyComponents, whose TGMediaPickerGalleryVideoItemView references
    # MPVolumeView. The Telegram app target links MediaPlayer implicitly; a standalone app does not.
    linkopts = ["-framework", "MediaPlayer"],
    minimum_os_version = "15.0",
    infoplists = [":HarnessInfoPlist"],
    # `defaultPresentationStrings` force-unwraps getAppBundle().path(forResource: "Localizable"…),
    # and getAppBundle() is NSBundle.mainBundle for a plain app — so without these the harness
    # traps at launch the moment it builds a PresentationData.
    resources = [
        "//Telegram:AppStringResources",
        "//Telegram:GeneratedPresentationStrings/Resources/PresentationStrings.data",
        # The panel's icons (send, attach, mic, …) are `UIImage(bundleImageName:)` lookups into
        # this catalogue; without it they render blank and the panel looks broken.
        "//submodules/TelegramUI:TelegramUIAssets",
        # Sounds and animations (the send/mic/video button morphs are `.tgs` resources here).
        "//submodules/TelegramUI:TelegramUIResources",
        # The voice-record button and its overlay draw from LegacyComponents' own bundle.
        "//submodules/LegacyComponents:LegacyComponentsResources",
        "//submodules/LegacyComponents:LegacyComponentsAssets",
    ],
    deps = [
        "//Tests/Common:Main",
        ":ComposerHarnessLib",
    ],
    visibility = ["//Tests:__subpackages__"],
)

swift_library(
    name = "ComposerHarnessTestsLib",
    testonly = True,
    srcs = glob(["Tests/**/*.swift"]),
    deps = [
        "//submodules/TelegramUIPreferences",
        "//submodules/ChatPresentationInterfaceState",
        "//submodules/TextFormat",
        # `textInputStateContextQueryRangeAndType`, for the chat's autocomplete transforms
        # (`HarnessChatSideEditUndoTests`).
        "//submodules/ChatContextQuery",
        ":ComposerHarnessLib",
        ":HarnessAppContext",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/TelegramCore",
        "//submodules/AccountContext",
        # `ChatRichTextInputNode` / `ChatRichTextFormatAction`, for the engine regression tests.
        "//submodules/TelegramUI/Components/Chat/ChatInputTextNode",
        # `chatComposerInsertTextOnUsersBehalf` / `chatComposerInsertMention`: the chat's inserts on the
        # user's behalf, called as the chat calls them (`HarnessChatInserts`).
        "//submodules/TelegramUI/Components/Chat/ChatTextInputPanelNode",
        # `@testable`, for the fuzz test: it asks the engine's own presentation / derived-view
        # verifiers after every step instead of letting them trap the test process.
        "//submodules/TelegramUI/Components/RichTextEditor:RichTextEngineEditor",
        # `Document` / `RichTextEditorClipboard`, for the drag-and-drop tests' fragments.
        "//submodules/TelegramUI/Components/RichTextEditor:RichTextEditorCore",
        "//submodules/TelegramUI/Components/RichTextEditor:RichTextEditorUIKit",
    ],
)

ios_unit_test(
    name = "ComposerHarnessTests",
    # Reuse ONE named simulator per device/OS ("BAZEL_TEST_<device>_<os>"). Without it the runner asks
    # xctestrunner for a fresh "New-<device>-<os>" simulator per run, and those were left BOOTED —
    # 23 of them after one session, slowing the machine (2026-09-23).
    env = {"REUSE_GLOBAL_SIMULATOR": "1"},
    linkopts = ["-framework", "MediaPlayer"],
    minimum_os_version = "15.0",
    runner = ":HarnessTestRunner",
    test_host = ":ComposerHarness",
    deps = [":ComposerHarnessTestsLib"],
    visibility = ["//Tests:__subpackages__"],
)

swift_library(
    name = "ComposerHarnessUITestsLib",
    testonly = True,
    srcs = glob(["UITests/**/*.swift"]),
)

ios_ui_test(
    name = "ComposerHarnessUITests",
    # Reuse ONE named simulator per device/OS ("BAZEL_TEST_<device>_<os>"). Without it the runner asks
    # xctestrunner for a fresh "New-<device>-<os>" simulator per run, and those were left BOOTED —
    # 23 of them after one session, slowing the machine (2026-09-23).
    env = {"REUSE_GLOBAL_SIMULATOR": "1"},
    minimum_os_version = "15.0",
    runner = ":HarnessUITestRunner",
    test_host = ":ComposerHarness",
    deps = [":ComposerHarnessUITestsLib"],
    visibility = ["//Tests:__subpackages__"],
)
