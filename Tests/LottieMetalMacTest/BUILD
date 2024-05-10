load("@build_bazel_rules_apple//apple:macos.bzl",
    "macos_application",
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
    name = "MacAppInfoPlist",
    extension = "plist",
    template = 
    """
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>$(EXECUTABLE_NAME)</string>
    <key>CFBundleIdentifier</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Telegram</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>NSMainStoryboardFile</key>
    <string>Main</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
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

swift_library(
    name = "MacLib",
    srcs = glob([
        "MacSources/**/*.swift",
    ]),
    data = [
        "Resources/Main.storyboard",
    ],
)

macos_application(
    name = "LottieMetalMacTest",
    app_icons = [],
    bundle_id = "com.example.hello-world-swift",
    infoplists = [
        ":MacAppInfoPlist",
        ":BuildNumberInfoPlist",
        ":VersionInfoPlist",
    ],
    minimum_os_version = "10.13",
    deps = [
        ":MacLib"
    ],
    visibility = ["//visibility:public"],
)

xcodeproj(
    name = "LottieMetalMacTest_xcodeproj",
    build_mode = "bazel",
    bazel_path = telegram_bazel_path,
    project_name = "LottieMetalMacTest",
    tags = ["manual"],
    top_level_targets = top_level_targets(
        labels = [
            ":LottieMetalMacTest",
        ],
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
