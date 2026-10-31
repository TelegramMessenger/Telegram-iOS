load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_application", "ios_ui_test", "ios_unit_test")
load("@build_bazel_rules_apple//apple:resources.bzl", "apple_resource_group")
load("//build-system/bazel-utils:plist_fragment.bzl", "plist_fragment")
load("@build_bazel_rules_apple//apple/testing/default_runner:ios_test_runner.bzl", "ios_test_runner")
load("@rules_shell//shell:sh_binary.bzl", "sh_binary")

# The widget harness: the REAL chat bubbles hosting message widgets, over the composer harness's synthetic app
# context (Tests/ComposerHarness/AppContext). Its operating manual is CLAUDE.md here.

# Runs before every harness test: the reused test simulator would otherwise keep the previous build.
sh_binary(
    name = "UninstallWidgetHarnessFromTestSims",
    srcs = ["Tools/uninstall_widget_harness_from_test_sims.sh"],
)

ios_test_runner(
    name = "WidgetHarnessTestRunner",
    pre_action = ":UninstallWidgetHarnessFromTestSims",
    device_type = "iPhone 17",
    os_version = "26.5",
)

ios_test_runner(
    name = "WidgetHarnessUITestRunner",
    pre_action = ":UninstallWidgetHarnessFromTestSims",
    device_type = "iPhone 18 Pro",
    os_version = "27.0",
)

plist_fragment(
    name = "WidgetHarnessInfoPlist",
    extension = "plist",
    template = """
    <key>CFBundleIdentifier</key>
    <string>org.telegram.WidgetHarness</string>
    <key>CFBundleName</key>
    <string>WidgetHarness</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>UILaunchScreen</key>
    <dict/>
    <key>CADisableMinimumFrameDurationOnPhone</key>
    <true/>
    <key>UISupportedInterfaceOrientations</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
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

# The conformance set's committed baseline, at Conformance/baseline.json in the app bundle (ConformanceSetTests).
apple_resource_group(
    name = "WidgetHarnessConformanceBaseline",
    structured_resources = glob(["Conformance/baseline.json"], allow_empty = True),
)

# The harness's own widgets, at Fixtures/ in the app bundle (`-widget-set fixture`).
apple_resource_group(
    name = "WidgetHarnessFixtures",
    structured_resources = glob(["Fixtures/**"]),
)

swift_library(
    name = "WidgetHarnessLib",
    module_name = "WidgetHarnessLib",
    srcs = glob(["Sources/**/*.swift"]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//Tests/ComposerHarness:HarnessAppContext",
        "//submodules/AsyncDisplayKit",
        "//submodules/Display",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/TelegramCore",
        "//submodules/TelegramPresentationData",
        "//submodules/TelegramUIPreferences",
        "//submodules/AccountContext",
        "//submodules/ChatPresentationInterfaceState",
        "//submodules/TelegramUI/Components/ChatControllerInteraction",
        "//submodules/TelegramUI/Components/Chat/ChatHistoryEntry",
        "//submodules/TelegramUI/Components/Chat/ChatMessageItem",
        "//submodules/TelegramUI/Components/Chat/ChatMessageItemCommon",
        "//submodules/TelegramUI/Components/Chat/ChatMessageItemImpl",
        "//submodules/TelegramUI/Components/Chat/ChatMessageBubbleContentNode",
        "//submodules/TelegramUI/Components/Chat/ChatMessageBubbleItemNode",
        "//submodules/TelegramUI/Components/Chat/ChatHistoryListViewBackend",
        "//submodules/TelegramUI/Components/Chat/ChatMessageShareButton",
        "//submodules/TelegramUI/Components/Chat/ChatMessageWidgetBubbleContentNode",
        "//submodules/TelegramUI/Components/MessageWidget/MessageWidget",
        "//submodules/TelegramUI/Components/MessageWidget/MessageWidgetStress",
        "//submodules/TelegramUI/Components/UnsupportedContentPill",
        "//submodules/TextSelectionNode",
        "//submodules/UndoUI",
    ],
    visibility = ["//Tests:__subpackages__"],
)

ios_application(
    name = "WidgetHarness",
    bundle_id = "org.telegram.WidgetHarness",
    families = ["iphone"],
    # As the composer harness: LegacyComponents references MPVolumeView, which a standalone app must link itself.
    linkopts = ["-framework", "MediaPlayer"],
    minimum_os_version = "15.0",
    infoplists = [":WidgetHarnessInfoPlist"],
    resources = [
        "//Telegram:AppStringResources",
        "//Telegram:GeneratedPresentationStrings/Resources/PresentationStrings.data",
        "//submodules/TelegramUI:TelegramUIAssets",
        "//submodules/TelegramUI:TelegramUIResources",
        "//submodules/LegacyComponents:LegacyComponentsResources",
        "//submodules/LegacyComponents:LegacyComponentsAssets",
        "//third-party/widget-sandbox:WidgetConformanceBundle",
        "//third-party/widget-sandbox:WidgetCorpusBundle",
        "//third-party/widget-sandbox:WidgetStressBundle",
        ":WidgetHarnessFixtures",
        ":WidgetHarnessConformanceBaseline",
    ],
    deps = [
        "//Tests/Common:Main",
        ":WidgetHarnessLib",
    ],
    visibility = ["//Tests:__subpackages__"],
)

swift_library(
    name = "WidgetHarnessTestsLib",
    testonly = True,
    srcs = glob(["Tests/**/*.swift"]),
    deps = [
        ":WidgetHarnessLib",
        "//Tests/ComposerHarness:HarnessAppContext",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/TelegramCore",
        "//submodules/TelegramPresentationData",
        "//submodules/TelegramUIPreferences",
        # The app's widget theme, for the conformance runner's tests.
        "//submodules/TelegramUI/Components/Chat/ChatMessageItemCommon",
        "//submodules/TelegramUI/Components/Chat/ChatMessageWidgetBubbleContentNode",
        # The date over a widget, for the safe area tests.
        "//submodules/TelegramUI/Components/Chat/ChatMessageDateAndStatusNode",
        # AccountContext, in MessageWidgetNetwork's signatures, for the network tests.
        "//submodules/AccountContext",
        # MessageWidgetKillSwitch and MessageWidgetView, for the availability tests.
        "//submodules/TelegramUI/Components/MessageWidget/MessageWidget",
        # The stress kit's runner, for its smoke test.
        "//submodules/TelegramUI/Components/MessageWidget/MessageWidgetStress",
        # TextSelectionNodeView and its node, for the selection tests.
        "//submodules/AsyncDisplayKit",
        # TapLongTapOrDoubleTapGestureRecognizer's long-tap policy, for the gesture tests.
        "//submodules/Display",
        "//submodules/TextSelectionNode",
        # WRSession and WREffectStore, for the effect tests (CSS filters paint only where there is a Metal device).
        "//submodules/TelegramUI/Components/MessageWidget/WidgetRuntimeIOS",
        # The chat backend's list and its scroll engine (`@testable`), for the resize test that releases the pin as a
        # drag does, without a finger.
        "//submodules/TelegramUI/Components/Chat/ChatHistoryListViewBackend",
        "//submodules/TelegramUI/Components/CoreList",
    ],
)

ios_unit_test(
    name = "WidgetHarnessTests",
    env = {"REUSE_GLOBAL_SIMULATOR": "1"},
    # ConformanceSetTests runs the 40 runs of the conformance set, each waiting up to 20 s.
    size = "large",
    linkopts = ["-framework", "MediaPlayer"],
    minimum_os_version = "15.0",
    runner = ":WidgetHarnessTestRunner",
    test_host = ":WidgetHarness",
    deps = [":WidgetHarnessTestsLib"],
    visibility = ["//Tests:__subpackages__"],
)

swift_library(
    name = "WidgetHarnessUITestsLib",
    testonly = True,
    srcs = glob(["UITests/**/*.swift"]),
)

ios_ui_test(
    name = "WidgetHarnessUITests",
    env = {"REUSE_GLOBAL_SIMULATOR": "1"},
    # Every test launches the harness app (36, about 300 s on a loaded machine: past medium's limit).
    size = "large",
    minimum_os_version = "15.0",
    runner = ":WidgetHarnessUITestRunner",
    test_host = ":WidgetHarness",
    deps = [":WidgetHarnessUITestsLib"],
    visibility = ["//Tests:__subpackages__"],
)
