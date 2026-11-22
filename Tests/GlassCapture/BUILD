load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_application")
load("//build-system/bazel-utils:plist_fragment.bzl", "plist_fragment")

# A capture harness: the real GlassBackgroundView at a sweep of radii over a plain page, for screenshots on an iOS 27
# simulator (the in-chat glass is being replaced by cached stretchable images made to look like it). Launch arguments
# pick the page colour, light or dark, the tint and the set; the app writes Documents/manifest.json with the shapes'
# frames once the glass has rendered.
plist_fragment(
    name = "GlassCaptureInfoPlist",
    extension = "plist",
    template = """
    <key>CFBundleIdentifier</key>
    <string>org.telegram.GlassCapture</string>
    <key>CFBundleName</key>
    <string>GlassCapture</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>UILaunchScreen</key>
    <dict/>
    <key>UIStatusBarHidden</key>
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

swift_library(
    name = "GlassCaptureLib",
    module_name = "GlassCaptureLib",
    srcs = glob(["Sources/**/*.swift"]),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        "//submodules/ComponentFlow",
        "//submodules/TelegramUI/Components/GlassBackgroundComponent",
        "//submodules/TelegramUI/Components/StaticGlassBackground",
    ],
)

ios_application(
    name = "GlassCapture",
    bundle_id = "org.telegram.GlassCapture",
    families = ["iphone"],
    minimum_os_version = "15.0",
    infoplists = [":GlassCaptureInfoPlist"],
    resources = [
        "//submodules/TelegramUI:StaticGlassResources",
    ],
    deps = [
        "//Tests/Common:Main",
        ":GlassCaptureLib",
    ],
)
