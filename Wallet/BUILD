load("@build_bazel_rules_apple//apple:ios.bzl",
    "ios_application",
    "ios_extension",
    "ios_framework",
)

load("@build_bazel_rules_swift//swift:swift.bzl",
    "swift_library",
)

load("//build-system/bazel-utils:plist_fragment.bzl",
    "plist_fragment",
)

load(
    "//build-input/data:variables.bzl",
    "wallet_build_number",
    "wallet_version",
    "wallet_bundle_id",
    "wallet_team_id",
)

config_setting(
    name = "debug",
    values = {
        "compilation_mode": "dbg",
    },
)

genrule(
    name = "empty",
    outs = ["empty.swift"],
    cmd = "touch $(OUTS)",
)

swift_library(
    name = "_LocalDebugOptions",
    srcs = [":empty"],
    copts = [
        "-Xfrontend",
        "-serialize-debugging-options",
    ],
    deps = [
    ],
    module_name = "_LocalDebugOptions",
    tags = ["no-remote"],
    visibility = ["//visibility:public"],
)

debug_deps = select({
    ":debug": [":_LocalDebugOptions"],
    "//conditions:default": [],
})

plist_fragment(
    name = "WalletInfoPlist",
    extension = "plist",
    template =
    """
    <key>CFBundleShortVersionString</key>
    <string>{wallet_version}</string>
    <key>CFBundleVersion</key>
    <string>{wallet_build_number}</string>
    <key>CFBundleAllowMixedLocalizations</key>
    <true/>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>TON Wallet</string>
    <key>CFBundleIdentifier</key>
    <string>{wallet_bundle_id}</string>
    <key>CFBundleName</key>
    <string>TON Wallet</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>ITSAppUsesNonExemptEncryption</key>
    <false/>
    <key>LSRequiresIPhoneOS</key>
    <true/>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key>
        <true/>
    </dict>
    <key>NSCameraUsageDescription</key>
    <string>Please allow TON Wallet access to your camera for scanning QR codes.</string>
    <key>NSFaceIDUsageDescription</key>
    <string>For better security, please allow TON Wallet to use your Face ID to authenticate payments.</string>
    <key>NSPhotoLibraryUsageDescription</key>
    <string>Please allow TON Wallet access to your Photo Stream in case you need to scan a QR code from a picture.</string>
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
        <string>armv7</string>
    </array>
    <key>UIRequiresPersistentWiFi</key>
    <true/>
    <key>UIStatusBarStyle</key>
    <string>UIStatusBarStyleLightContent</string>
    <key>UISupportedInterfaceOrientations</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
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
    """.format(
        wallet_version = wallet_version,
        wallet_build_number = wallet_build_number,
        wallet_bundle_id = wallet_bundle_id,
    )
)

filegroup(
    name = "Strings",
    srcs = glob([
        "Strings/**/*",
    ], exclude = ["Strings/**/.*"]),
)

filegroup(
    name = "Icons",
    srcs = glob([
        "Icons.xcassets/**/*",
    ], exclude = ["Icons.xcassets/**/.*"]),
)

objc_library(
    name = "Main",
    srcs = [
        "Sources/main.m"
    ],
)

swift_library(
    name = "Lib",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    data = [
        
    ],
    deps = [
        "//submodules/WalletUI:WalletUI",
        "//submodules/WalletCore:WalletCore",
        "//submodules/BuildConfig:BuildConfig",
        "//submodules/OverlayStatusController:OverlayStatusController",
    ],
)

ios_application(
    name = "Wallet",
    bundle_id = wallet_bundle_id,
    families = ["iphone", "ipad"],
    minimum_os_version = "9.0",
    provisioning_profile = "//build-input/data/provisioning-profiles:Wallet.mobileprovision",
    infoplists = [
        ":WalletInfoPlist.plist",
    ],
    app_icons = [
        ":Icons",
    ],
    launch_storyboard = "LaunchScreen.xib",
    strings = [
        ":Strings",
    ],
    deps = [
        ":Main",
        ":Lib",
    ],
)
