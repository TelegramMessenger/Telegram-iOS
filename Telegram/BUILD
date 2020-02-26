load("@build_bazel_rules_apple//apple:ios.bzl",
    "ios_application",
    "ios_framework",
)

load("@build_bazel_rules_apple//apple:watchos.bzl",
    "watchos_application",
    "watchos_extension",
)

load("@build_bazel_rules_apple//apple:versioning.bzl",
    "apple_bundle_version",
)

load("@build_bazel_rules_swift//swift:swift.bzl",
    "swift_library",
)

load("//build-system:plist_fragment.bzl",
    "plist_fragment",
)

load(
    "//build-input/data:variables.bzl",
    "telegram_build_number",
    "telegram_version",
    "telegram_bundle_id",
    "telegram_aps_environment",
)

filegroup(
    name = "AppResources",
    srcs = glob([
        "Telegram-iOS/Resources/**/*",
    ], exclude = ["Telegram-iOS/Resources/**/.*"]),
)

filegroup(
    name = "AppStringResources",
    srcs = glob([
        "Telegram-iOS/*.lproj/Localizable.strings",
    ], exclude = ["Telegram-iOS/*.lproj/**/.*"]),
)

filegroup(
    name = "WatchAppStringResources",
    srcs = glob([
        "Telegram-iOS/*.lproj/Localizable.strings",
    ], exclude = ["Telegram-iOS/*.lproj/**/.*"]),
)

filegroup(
    name = "AppIntentVocabularyResources",
    srcs = glob([
        "Telegram-iOS/*.lproj/AppIntentVocabulary.plist",
    ], exclude = ["Telegram-iOS/*.lproj/**/.*"]),
)

filegroup(
    name = "InfoPlistStringResources",
    srcs = glob([
        "Telegram-iOS/*.lproj/InfoPlist.strings",
    ], exclude = ["Telegram-iOS/*.lproj/**/.*"]),
)

filegroup(
    name = "Icons",
    srcs = glob([
        "Telegram-iOS/Icons.xcassets/**/*",
    ], exclude = ["Telegram-iOS/Icons.xcassets/**/.*"]),
)

filegroup(
    name = "AppIcons",
    srcs = glob([
        "Telegram-iOS/AppIcons.xcassets/**/*",
    ], exclude = ["Telegram-iOS/AppIcons.xcassets/**/.*"]),
)

filegroup(
    name = "DefaultAppIcon",
    srcs = glob([
        "Telegram-iOS/DefaultAppIcon.xcassets/**/*",
    ], exclude = ["Telegram-iOS/DefaultAppIcon.xcassets/**/.*"]),
)

filegroup(
    name = "AdditionalIcons",
    srcs = glob([
        "Telegram-iOS/*.png",
    ]),
)

filegroup(
    name = "LaunchScreen",
    srcs = glob([
        "Telegram-iOS/Base.lproj/LaunchScreen.xib",
    ]),
)

objc_library(
    name = "Main",
    srcs = [
        "Telegram-iOS/main.m"
    ],
)

swift_library(
    name = "Lib",
    srcs = glob([
        "Telegram-iOS/Application.swift",
    ]),
    data = [
        ":AppResources",
        ":AppIntentVocabularyResources",
        ":InfoPlistStringResources",
    ],
    deps = [
        "//submodules/TelegramUI:TelegramUI",
    ],
)

plist_fragment(
    name = "AdditionalInfoPlist",
    extension = "plist",
    template =
    """
    <key>CFBundleShortVersionString</key>
        <string>{telegram_version}</string>
        <key>CFBundleVersion</key>
        <string>{telegram_build_number}</string>
        <key>CFBundleURLTypes</key>
        <array>
            <dict>
                <key>CFBundleTypeRole</key>
                <string>Viewer</string>
                <key>CFBundleURLName</key>
                <string>{telegram_bundle_id}</string>
                <key>CFBundleURLSchemes</key>
                <array>
                    <string>telegram</string>
                </array>
            </dict>
            <dict>
                <key>CFBundleTypeRole</key>
                <string>Viewer</string>
                <key>CFBundleURLName</key>
                <string>{telegram_bundle_id}.ton</string>
                <key>CFBundleURLSchemes</key>
                <array>
                    <string>ton</string>
                </array>
            </dict>
            <dict>
                <key>CFBundleTypeRole</key>
                <string>Viewer</string>
                <key>CFBundleURLName</key>
                <string>{telegram_bundle_id}.compatibility</string>
                <key>CFBundleURLSchemes</key>
                <array>
                    <string>tg</string>
                </array>
            </dict>
        </array>
    """.format(
        telegram_version = telegram_version,
        telegram_build_number = telegram_build_number,
        telegram_bundle_id = telegram_bundle_id,
    )
)

official_apple_pay_merchants = [
    "merchant.ph.telegra.Telegraph",
    "merchant.yandex.ph.telegra.Telegraph",
    "merchant.sberbank.ph.telegra.Telegraph",
    "merchant.sberbank.test.ph.telegra.Telegraph",
    "merchant.privatbank.test.telergramios",
    "merchant.privatbank.prod.telergram",
    "merchant.telegram.tranzzo.test",
]

apple_pay_merchants = official_apple_pay_merchants if telegram_bundle_id == "ph.telegra.Telegraph" else ""

apple_pay_merchants_fragment = "" if apple_pay_merchants == "" else """
<key>com.apple.developer.in-app-payments</key>
<array>
""" + "\n".join([
"    <string>{}</string>".format(merchant_id) for merchant_id in apple_pay_merchants
]) + "\n" + """
</array>
"""

telegram_entitlements_template = """
    <key>com.apple.developer.icloud-services</key>
    <array>
        <string>CloudKit</string>
        <string>CloudDocuments</string>
    </array>
    <key>com.apple.developer.icloud-container-identifiers</key>
    <array>
        <string>iCloud.{telegram_bundle_id}</string>
    </array>
    <key>aps-environment</key>
    <string>{telegram_aps_environment}</string>
    <key>com.apple.developer.associated-domains</key>
    <array>
        <string>applinks:telegram.me</string>
        <string>applinks:t.me</string>
    </array>
    <key>com.apple.developer.siri</key>
    <true/>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.{telegram_bundle_id}</string>
    </array>
    <key>com.apple.developer.pushkit.unrestricted-voip</key>
    <true/>
""" + apple_pay_merchants_fragment

plist_fragment(
    name = "TelegramEntitlements",
    extension = "entitlements",
    template = telegram_entitlements_template.format(
        telegram_bundle_id = telegram_bundle_id,
        telegram_aps_environment = telegram_aps_environment,
    )
)

filegroup(
    name = "TelegramWatchExtensionResources",
    srcs = glob([
        "Watch/Extension/Resources/**/*",
    ], exclude = ["Watch/Extension/Resources/**/.*"]),
)

filegroup(
    name = "TelegramWatchAppResources",
    srcs = glob([
        "Watch/Extension/Resources/**/*.png",
    ], exclude = ["Watch/Extension/Resources/**/.*"]),
)

filegroup(
    name = "TelegramWatchAppAssets",
    srcs = glob([
        "Watch/App/Assets.xcassets/**/*",
    ], exclude = ["Watch/App/Assets.xcassets/**/.*"]),
)

filegroup(
    name = "TelegramWatchAppInterface",
    srcs = glob([
        "Watch/App/Base.lproj/Interface.storyboard",
    ]),
)

objc_library(
    name = "TelegramWatchLib",
    srcs = glob([
        "Watch/Extension/**/*.m",
        "Watch/SSignalKit/**/*.m",
        "Watch/Bridge/**/*.m",
        "Watch/WatchCommonWatch/**/*.m",
        "Watch/Extension/**/*.h",
        "Watch/SSignalKit/**/*.h",
        "Watch/Bridge/**/*.h",
        "Watch/WatchCommonWatch/**/*.h",
    ]),
    copts = [
        "-DTARGET_OS_WATCH=1",
        "-ITelegram/Watch",
        "-ITelegram/Watch/Extension",
        "-ITelegram/Watch/Bridge",
    ],
    sdk_frameworks = [
        "WatchKit",
        "WatchConnectivity",
        "ClockKit",
        "UserNotifications",
        "CoreLocation",
        "CoreGraphics",
    ],
)

plist_fragment(
    name = "WatchVersionInfoPlist",
    extension = "plist",
    template =
    """
    <key>CFBundleShortVersionString</key>
    <string>{telegram_version}</string>
    <key>CFBundleVersion</key>
    <string>{telegram_build_number}</string>
    """.format(
        telegram_version = telegram_version,
        telegram_build_number = telegram_build_number,
    )
)

plist_fragment(
    name = "WatchAppNameInfoPlist",
    extension = "plist",
    template =
    """
    <key>CFBundleDisplayName</key>
    <string>Telegram</string>
    """
)

plist_fragment(
    name = "WatchExtensionNSExtensionInfoPlist",
    extension = "plist",
    template =
    """
    <key>NSExtension</key>
    <dict>
        <key>NSExtensionAttributes</key>
        <dict>
            <key>WKAppBundleIdentifier</key>
            <string>{telegram_bundle_id}.watchkitapp</string>
        </dict>
        <key>NSExtensionPointIdentifier</key>
        <string>com.apple.watchkit</string>
    </dict>
    """.format(
        telegram_bundle_id = telegram_bundle_id,
    )
)

plist_fragment(
    name = "WatchAppCompanionInfoPlist",
    extension = "plist",
    template =
    """
    <key>WKCompanionAppBundleIdentifier</key>
    <string>{telegram_bundle_id}</string>
    """.format(
        telegram_bundle_id = telegram_bundle_id,
    )
)

watchos_extension(
    name = "TelegramWatchExtension",
    bundle_id = "{telegram_bundle_id}.watchkitapp.watchkitextension".format(
        telegram_bundle_id = telegram_bundle_id,
    ),
    bundle_name = "TelegramWatchExtension",
    infoplists = [
        "Watch/Extension/Info.plist",
        ":WatchVersionInfoPlist",
        ":WatchAppNameInfoPlist",
        ":WatchExtensionNSExtensionInfoPlist",
    ],
    minimum_os_version = "5.0",
    provisioning_profile = "//build-input/data/provisioning-profiles:WatchExtension.mobileprovision",
    resources = [
        ":TelegramWatchExtensionResources",
    ],
    strings = [
        ":WatchAppStringResources",
    ],
    deps = [
        ":TelegramWatchLib",
    ],
)

watchos_application(
    name = "TelegramWatchApp",
    #app_icons = ,
    bundle_id = "{telegram_bundle_id}.watchkitapp".format(
        telegram_bundle_id = telegram_bundle_id,
    ),
    bundle_name = "TelegramWatch",
    extension = ":TelegramWatchExtension",
    infoplists = [
        "Watch/App/Info.plist",
        ":WatchVersionInfoPlist",
        ":WatchAppNameInfoPlist",
        ":WatchAppCompanionInfoPlist",
    ],
    minimum_os_version = "5.0",
    provisioning_profile = "//build-input/data/provisioning-profiles:WatchApp.mobileprovision",
    resources = [
        ":TelegramWatchAppResources",
        ":TelegramWatchAppAssets",
    ],
    storyboards = [
        ":TelegramWatchAppInterface",
    ],
    strings = [
    ],
)

ios_application(
    name = "Telegram",
    bundle_id = "{telegram_bundle_id}".format(
        telegram_bundle_id = telegram_bundle_id,
    ),
    families = ["iphone", "ipad"],
    minimum_os_version = "9.0",
    provisioning_profile = "//build-input/data/provisioning-profiles:Telegram.mobileprovision",
    entitlements = ":TelegramEntitlements.entitlements",
    infoplists = [
        "Info.plist",
        ":AdditionalInfoPlist",
    ],
    app_icons = [
        ":DefaultAppIcon",
    ],
    frameworks = [
        #":AsyncDisplayKitFramework",
    ],
    strings = [
        ":AppStringResources",
    ],
    watch_application = ":TelegramWatchApp",
    deps = [
        ":Main",
        ":Lib",
    ],
)
