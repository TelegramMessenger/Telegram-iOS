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
    "@build_bazel_rules_apple//apple:resources.bzl",
    "apple_resource_bundle",
    "apple_resource_group",
)

load(
    "@rules_xcodeproj//xcodeproj:defs.bzl",
    "top_level_target",
    "top_level_targets",
    "xcodeproj",
    "xcode_provisioning_profile",
)

load("@build_bazel_rules_apple//apple:apple.bzl", "local_provisioning_profile")

load(
    "@build_configuration//:variables.bzl",
    "telegram_bazel_path",
)

filegroup(
    name = "AppResources",
    srcs = glob([
        "Resources/**/*",
    ], exclude = ["Resources/**/.*"]),
)

swift_library(
    name = "Lib",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    data = [
        ":AppResources",
    ],
    deps = [
        "//submodules/Display",
        "//submodules/MetalEngine",
        "//submodules/LottieCpp",
        "//submodules/TelegramUI/Components/LottieMetal",
        "//submodules/rlottie:RLottieBinding",
        "//Tests/LottieMetalTest/QOILoader",
        "//Tests/LottieMetalTest/SoftwareLottieRenderer",
        "//Tests/LottieMetalTest/LottieSwift",
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
    <string>1.0</string>
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
        <string>armv7</string>
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
    """
)

filegroup(
    name = "TestDataBundleFiles",
    srcs = glob([
        "TestData/*.json",
    ]),
    visibility = ["//visibility:public"],
)

plist_fragment(
    name = "TestDataBundleInfoPlist",
    extension = "plist",
    template =
    """
    <key>CFBundleIdentifier</key>
    <string>org.telegram.TestDataBundle</string>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleName</key>
    <string>TestDataBundle</string>
    """
)

apple_resource_bundle(
    name = "TestDataBundle",
    infoplists = [
        ":TestDataBundleInfoPlist",
    ],
    resources = [
        ":TestDataBundleFiles",
    ],
)

ios_application(
    name = "LottieMetalTest",
    bundle_id = "ph.telegra.Telegraph",
    families = ["iphone", "ipad"],
    minimum_os_version = "12.0",
    provisioning_profile = "@build_configuration//provisioning:Telegram.mobileprovision",
    infoplists = [
        ":AppInfoPlist",
        ":BuildNumberInfoPlist",
        ":VersionInfoPlist",
    ],
    resources = [
        "//Tests/Common:LaunchScreen",
        ":TestDataBundle",
        "//Tests/LottieMetalTest/skia",
    ],
    frameworks = [
    ],
    deps = [
        "//Tests/Common:Main",
        ":Lib",
    ],
    visibility = ["//visibility:public"],
)

xcodeproj(
    name = "LottieMetalTest_xcodeproj",
    build_mode = "bazel",
    bazel_path = telegram_bazel_path,
    project_name = "LottieMetalTest",
    tags = ["manual"],
    top_level_targets = top_level_targets(
        labels = [
            ":LottieMetalTest",
        ],
        target_environments = ["device", "simulator"],
    ),
    xcode_configurations = {
        "Debug": {
            "//command_line_option:compilation_mode": "dbg",
        },
        "Release": {
            "//command_line_option:compilation_mode": "opt",
        },
    },
    default_xcode_configuration = "Debug"
)
