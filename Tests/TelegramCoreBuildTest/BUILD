load("@build_bazel_rules_apple//apple:ios.bzl",
    "ios_application",
)

load("@build_bazel_rules_swift//swift:swift.bzl",
    "swift_library",
)

load("//build-system/bazel-utils:plist_fragment.bzl",
    "plist_fragment",
)

load(
    "@build_configuration//:variables.bzl",
    "telegram_bundle_id",
    "telegram_aps_environment",
    "telegram_team_id",
    "telegram_enable_icloud",
    "telegram_enable_siri",
    "telegram_enable_watch",
)

module_name = "TelegramCoreBuildTest"

swift_library(
    name = "Lib",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    data = [
    ],
    deps = [
    ],
)

plist_fragment(
    name = "BuildNumberInfoPlist",
    extension = "plist",
    template =
    """
    <key>CFBundleVersion</key>
    <string>1</string>
    """
)

plist_fragment(
    name = "VersionInfoPlist",
    extension = "plist",
    template =
    """
    <key>CFBundleShortVersionString</key>
    <string>{telegramVersion}</string>
    """
)

plist_fragment(
    name = "AppNameInfoPlist",
    extension = "plist",
    template =
    """
    <key>CFBundleDisplayName</key>
    <string>Test</string>
    """
)

plist_fragment(
    name = "AppInfoPlist",
    extension = "plist",
    template = 
    """
    <key>CFBundleAllowMixedLocalizations</key>
    <true/>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>Test</string>
    <key>CFBundleIdentifier</key>
    <string>ph.telegra.Telegraph</string>
    <key>CFBundleName</key>
    <string>Telegram</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleSignature</key>
    <string>????</string>
    <key>ITSAppUsesNonExemptEncryption</key>
    <false/>
    <key>LSRequiresIPhoneOS</key>
    <true/>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key>
        <true/>
    </dict>
    <key>UIDeviceFamily</key>
    <array>
        <integer>1</integer>
        <integer>2</integer>
    </array>
    <key>UIFileSharingEnabled</key>
    <false/>
    <key>UILaunchStoryboardName</key>
    <string>LaunchScreen</string>
    <key>UIRequiredDeviceCapabilities</key>
    <array>
        <string>arm64</string>
    </array>
    <key>UIStatusBarStyle</key>
    <string>UIStatusBarStyleDefault</string>
    <key>UISupportedInterfaceOrientations</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
        <string>UIInterfaceOrientationLandscapeLeft</string>
        <string>UIInterfaceOrientationLandscapeRight</string>
    </array>
    <key>UISupportedInterfaceOrientations~ipad</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
        <string>UIInterfaceOrientationPortraitUpsideDown</string>
        <string>UIInterfaceOrientationLandscapeLeft</string>
        <string>UIInterfaceOrientationLandscapeRight</string>
    </array>
    <key>UIViewControllerBasedStatusBarAppearance</key>
    <false/>
    <key>UIViewEdgeAntialiasing</key>
    <false/>
    <key>UIViewGroupOpacity</key>
    <false/>
    <key>CADisableMinimumFrameDurationOnPhone</key>
    <true/>
    """.format(module_name=module_name)
)

ios_application(
    name = module_name,
    bundle_id = "ph.telegra.Telegraph",
    families = ["iphone", "ipad"],
    minimum_os_version = "11.0",
    provisioning_profile = None,
    infoplists = [
        ":AppInfoPlist",
        ":BuildNumberInfoPlist",
        ":VersionInfoPlist",
    ],
    resources = [
        "//Tests/Common:LaunchScreen",
    ],
    extensions = [
        "//Telegram:WidgetExtension",
    ],
    deps = [
        "//Tests/Common:Main",
        ":Lib",
    ],
    visibility = ["//visibility:public"],
)
