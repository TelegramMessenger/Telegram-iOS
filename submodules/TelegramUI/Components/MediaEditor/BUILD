load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load(
    "@build_bazel_rules_apple//apple:resources.bzl",
    "apple_resource_bundle",
    "apple_resource_group",
)
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_application", "ios_unit_test")
load("@build_bazel_rules_apple//apple/testing/default_runner:ios_test_runner.bzl", "ios_test_runner")
load("//build-system/bazel-utils:plist_fragment.bzl",
    "plist_fragment",
)

filegroup(
    name = "MediaEditorMetalResources",
    srcs = glob([
        "MetalResources/**/*.*",
    ]),
    visibility = ["//visibility:public"],
)

plist_fragment(
    name = "MediaEditorBundleInfoPlist",
    extension = "plist",
    template =
    """
    <key>CFBundleIdentifier</key>
    <string>org.telegram.MediaEditor</string>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleName</key>
    <string>MediaEditor</string>
    """
)

apple_resource_bundle(
    name = "MediaEditorBundle",
    infoplists = [
        ":MediaEditorBundleInfoPlist",
    ],
    resources = [
        ":MediaEditorMetalResources",
    ],
)

swift_library(
    name = "MediaEditor",
    module_name = "MediaEditor",
    srcs = glob([
        "Sources/**/*.swift",
    ]),
    copts = [
        "-warnings-as-errors",
    ],
    data = [
        ":MediaEditorBundle",
    ],
    deps = [
        "//submodules/AsyncDisplayKit",
        "//submodules/Display",
        "//submodules/Postbox",
        "//submodules/TelegramCore",
        "//submodules/SSignalKit/SwiftSignalKit",
        "//submodules/TelegramPresentationData",
        "//submodules/TelegramUIPreferences",
        "//submodules/AccountContext",
        "//submodules/AppBundle",
        "//submodules/TextFormat",
        "//submodules/AnimatedStickerNode",
        "//submodules/TelegramAnimatedStickerNode",
        "//submodules/StickerResources",
        "//submodules/YuvConversion",
        "//submodules/FastBlur",
        "//submodules/WallpaperBackgroundNode",
        "//submodules/ImageTransparency",
        "//submodules/FFMpegBinding",
        "//submodules/TelegramUI/Components/AnimationCache/ImageDCT",
        "//submodules/FileMediaResourceStatus",
        "//submodules/TelegramUI/Components/MediaEditor/ImageObjectSeparation",
        "//submodules/TelegramUI/Components/MediaAssetsContext",
    ],
    visibility = [
        "//visibility:public",
    ],
)

apple_resource_group(
    name = "MediaEditorExportTestResources",
    structured_resources = glob([
        "Tests/Resources/**",
    ]),
)

apple_resource_group(
    name = "MediaEditorSourcesTestResources",
    structured_resources = glob([
        "Sources/**/*.swift",
    ]),
)

swift_library(
    name = "MediaEditorExportTestSupport",
    module_name = "MediaEditorExportTestSupport",
    testonly = True,
    srcs = glob([
        "Tests/**/*.swift",
    ], exclude = [
        "Tests/FixtureGenerator/**",
        "Tests/MediaEditorExportTests.swift",
        "Tests/MediaEditorCropPerspectiveTests.swift",
        "Tests/MediaEditorVignetteTests.swift",
    ]),
    copts = [
        "-O",
    ],
    data = [
        ":MediaEditorExportTestResources",
        ":MediaEditorSourcesTestResources",
    ],
    deps = [
        ":MediaEditor",
        "//submodules/Display",
        "//submodules/Postbox",
        "//submodules/TelegramCore",
        "//submodules/SSignalKit/SwiftSignalKit",
    ],
)

swift_library(
    name = "MediaEditorExportTestsLib",
    testonly = True,
    srcs = [
        "Tests/MediaEditorExportTests.swift",
        "Tests/MediaEditorCropPerspectiveTests.swift",
        "Tests/MediaEditorVignetteTests.swift",
    ],
    deps = [
        ":MediaEditorExportTestSupport",
        ":MediaEditor",
        "//submodules/TelegramCore",
    ],
)

plist_fragment(
    name = "MediaEditorExportHarnessInfoPlist",
    extension = "plist",
    template =
    """
    <key>CFBundleIdentifier</key>
    <string>org.telegram.MediaEditorExportHarness</string>
    <key>CFBundleName</key>
    <string>MediaEditorExportHarness</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>UILaunchScreen</key>
    <dict/>
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
                    <string>MediaEditorExportHarnessSceneDelegate</string>
                </dict>
            </array>
        </dict>
    </dict>
    """
)

swift_library(
    name = "MediaEditorExportHarnessLib",
    testonly = True,
    srcs = glob([
        "Harness/**/*.swift",
    ]),
    deps = [
        ":MediaEditorExportTestSupport",
    ],
)

ios_application(
    name = "MediaEditorExportHarness",
    testonly = True,
    bundle_id = "org.telegram.MediaEditorExportHarness",
    families = ["iphone"],
    minimum_os_version = "15.0",
    infoplists = [":MediaEditorExportHarnessInfoPlist"],
    deps = [
        ":MediaEditorExportHarnessLib",
    ],
)

ios_test_runner(
    name = "MediaEditorExportTestRunner",
    device_type = "iPhone 18 Pro",
    os_version = "27.0",
)

ios_unit_test(
    name = "MediaEditorExportTests",
    minimum_os_version = "15.0",
    runner = ":MediaEditorExportTestRunner",
    timeout = "eternal",
    deps = [
        ":MediaEditorExportTestsLib",
    ],
    visibility = [
        "//visibility:public",
    ],
)
