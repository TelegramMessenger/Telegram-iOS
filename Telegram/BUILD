load("@build_bazel_rules_apple//apple:ios.bzl",
    "ios_application",
    "ios_extension",
    "ios_framework",
)

load("@build_bazel_rules_apple//apple:watchos.bzl",
    "watchos_application",
    "watchos_extension",
)

load("@build_bazel_rules_swift//swift:swift.bzl",
    "swift_library",
)

load("//build-system/bazel-utils:plist_fragment.bzl",
    "plist_fragment",
)

load(
    "//build-input/data:variables.bzl",
    "telegram_build_number",
    "telegram_version",
    "telegram_bundle_id",
    "telegram_aps_environment",
    "telegram_team_id",
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
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/AppBundle:AppBundle",
        "//submodules/ObjCRuntimeUtils:ObjCRuntimeUtils",
        "//submodules/UIKitRuntimeUtils:UIKitRuntimeUtils",
        "//submodules/Crc32:Crc32",
        "//submodules/MurMurHash32:MurMurHash32",
        "//submodules/StringTransliteration:StringTransliteration",
        "//submodules/sqlcipher:sqlcipher",
        "//submodules/NumberPluralizationForm:NumberPluralizationForm",
        "//submodules/EncryptionProvider:EncryptionProvider",
        "//submodules/MtProtoKit:MtProtoKit",
    ],
    module_name = "_LocalDebugOptions",
    tags = ["no-remote"],
    visibility = ["//visibility:public"],
)

debug_deps = select({
    ":debug": [":_LocalDebugOptions"],
    "//conditions:default": [],
})

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
        "//submodules/LegacyComponents:LegacyComponentsResources",
        "//submodules/OverlayStatusController:OverlayStatusControllerResources",
        "//submodules/PasswordSetupUI:PasswordSetupUIResources",
        "//submodules/PasswordSetupUI:PasswordSetupUIAssets",
        "//submodules/TelegramUI:TelegramUIResources",
        "//submodules/TelegramUI:TelegramUIAssets",
        #"//submodules/WalletUI:WalletUIResources",
        #"//submodules/WalletUI:WalletUIAssets",
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

official_bundle_ids = [
    "ph.telegra.Telegraph",
    "org.telegram.Telegram-iOS",
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

official_unrestricted_voip_fragment = """
<key>com.apple.developer.pushkit.unrestricted-voip</key>
<true/>
"""
unrestricted_voip_fragment = official_unrestricted_voip_fragment if telegram_bundle_id in official_bundle_ids else ""

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
    <key>application-identifier</key>
    <string>{telegram_team_id}.{telegram_bundle_id}</string>
""" + apple_pay_merchants_fragment + unrestricted_voip_fragment

plist_fragment(
    name = "TelegramEntitlements",
    extension = "entitlements",
    template = telegram_entitlements_template.format(
        telegram_bundle_id = telegram_bundle_id,
        telegram_team_id = telegram_team_id,
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
    name = "VersionInfoPlist",
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
    name = "AppNameInfoPlist",
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

plist_fragment(
    name = "WatchExtensionInfoPlist",
    extension = "plist",
    template =
    """
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>$(EXECUTABLE_NAME)</string>
    <key>CFBundleIdentifier</key>
    <string>{telegram_bundle_id}.watchkitapp.watchkitextension</string>
    <key>CFBundleName</key>
    <string>Telegram</string>
    <key>CFBundlePackageType</key>
    <string>XPC!</string>
    <key>WKExtensionDelegateClassName</key>
    <string>TGExtensionDelegate</string>
    """.format(
        telegram_bundle_id = telegram_bundle_id,
    )
)

plist_fragment(
    name = "WatchAppInfoPlist",
    extension = "plist",
    template =
    """
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleIdentifier</key>
    <string>{telegram_bundle_id}.watchkitapp</string>
    <key>CFBundleName</key>
    <string>Telegram</string>
    <key>UISupportedInterfaceOrientations</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
        <string>UIInterfaceOrientationPortraitUpsideDown</string>
    </array>
    <key>WKWatchKitApp</key>
    <true/>
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
        ":WatchExtensionInfoPlist",
        ":VersionInfoPlist",
        ":AppNameInfoPlist",
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
        ":WatchAppInfoPlist",
        ":VersionInfoPlist",
        ":AppNameInfoPlist",
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

swift_library(
    name = "ShareExtensionLib",
    module_name = "ShareExtensionLib",
    srcs = glob([
        "Share/**/*.swift",
    ]),
    deps = [
        "//submodules/TelegramUI:TelegramUI"
    ],
)

plist_fragment(
    name = "TelegramUIInfoPlist",
    extension = "plist",
    template =
    """
    <key>CFBundleIdentifier</key>
    <string>{telegram_bundle_id}.TelegramUI</string>
    <key>CFBundleVersion</key>
    <string>{telegram_build_number}</string>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleName</key>
    <string>TelegramUI</string>
    <key>CFBundleShortVersionString</key>
    <string>{telegram_version}</string>
    """.format(
        telegram_bundle_id = telegram_bundle_id,
        telegram_version = telegram_version,
        telegram_build_number = telegram_build_number,
    )
)

ios_framework(
    name = "TelegramUIFramework",
    bundle_id = "{telegram_bundle_id}.TelegramUI".format(
        telegram_bundle_id = telegram_bundle_id,
    ),
    families = [
        "iphone",
        "ipad",
    ],
    infoplists = [
        ":TelegramUIInfoPlist",
    ],
    minimum_os_version = "9.0",
    deps = [
        "//submodules/TelegramUI:TelegramUI",
    ] + debug_deps,
)

plist_fragment(
    name = "ShareInfoPlist",
    extension = "plist",
    template = 
    """
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleIdentifier</key>
    <string>{telegram_bundle_id}.Share</string>
    <key>CFBundleName</key>
    <string>Telegram</string>
    <key>CFBundlePackageType</key>
    <string>XPC!</string>
    <key>NSExtension</key>
    <dict>
        <key>NSExtensionAttributes</key>
        <dict>
            <key>IntentsSupported</key>
            <array>
                <string>INSendMessageIntent</string>
            </array>
            <key>NSExtensionActivationRule</key>
            <string>SUBQUERY (
    extensionItems,
    $extensionItem,
    SUBQUERY (
        $extensionItem.attachments,
        $attachment,
        ANY $attachment.registeredTypeIdentifiers UTI-CONFORMS-TO "public.file-url" ||
        ANY $attachment.registeredTypeIdentifiers UTI-CONFORMS-TO "public.movie" ||
        ANY $attachment.registeredTypeIdentifiers UTI-CONFORMS-TO "public.image" ||
        ANY $attachment.registeredTypeIdentifiers UTI-CONFORMS-TO "public.url" ||
        ANY $attachment.registeredTypeIdentifiers UTI-CONFORMS-TO "public.text" ||
        ANY $attachment.registeredTypeIdentifiers UTI-CONFORMS-TO "public.audio" ||
        ANY $attachment.registeredTypeIdentifiers UTI-CONFORMS-TO "public.data" ||
        ANY $attachment.registeredTypeIdentifiers UTI-CONFORMS-TO "public.vcard" ||
        ANY $attachment.registeredTypeIdentifiers UTI-CONFORMS-TO "com.apple.pkpass"
    ).@count == $extensionItem.attachments.@count
).@count &gt; 0</string>
        </dict>
        <key>NSExtensionPointIdentifier</key>
        <string>com.apple.share-services</string>
        <key>NSExtensionPrincipalClass</key>
        <string>ShareRootController</string>
    </dict>
    """.format(
        telegram_bundle_id = telegram_bundle_id,
    )
)

ios_extension(
    name = "ShareExtension",
    bundle_id = "{telegram_bundle_id}.Share".format(
        telegram_bundle_id = telegram_bundle_id,
    ),
    families = [
        "iphone",
        "ipad",
    ],
    infoplists = [
        ":ShareInfoPlist",
        ":VersionInfoPlist",
        ":AppNameInfoPlist",
    ],
    minimum_os_version = "9.0",
    provisioning_profile = "//build-input/data/provisioning-profiles:Share.mobileprovision",
    deps = [":ShareExtensionLib"],
    frameworks = [
        ":TelegramUIFramework"
    ],
)

swift_library(
    name = "NotificationServiceExtensionLib",
    module_name = "NotificationServiceExtensionLib",
    srcs = glob([
        "NotificationServiceNext/**/*.swift",
    ]),
    deps = [
    ],
)

plist_fragment(
    name = "NotificationServiceInfoPlist",
    extension = "plist",
    template = 
    """
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleIdentifier</key>
    <string>{telegram_bundle_id}.NotificationService</string>
    <key>CFBundleName</key>
    <string>Telegram</string>
    <key>CFBundlePackageType</key>
    <string>XPC!</string>
    <key>NSExtension</key>
    <dict>
        <key>NSExtensionPointIdentifier</key>
        <string>com.apple.usernotifications.service</string>
        <key>NSExtensionPrincipalClass</key>
        <string>NotificationService</string>
    </dict>
    """.format(
        telegram_bundle_id = telegram_bundle_id,
    )
)

ios_extension(
    name = "NotificationServiceExtension",
    bundle_id = "{telegram_bundle_id}.NotificationService".format(
        telegram_bundle_id = telegram_bundle_id,
    ),
    families = [
        "iphone",
        "ipad",
    ],
    infoplists = [
        ":NotificationServiceInfoPlist",
        ":VersionInfoPlist",
        ":AppNameInfoPlist",
    ],
    minimum_os_version = "10.0",
    provisioning_profile = "//build-input/data/provisioning-profiles:NotificationService.mobileprovision",
    deps = [":NotificationServiceExtensionLib"],
    frameworks = [
    ],
)

plist_fragment(
    name = "TelegramInfoPlist",
    extension = "plist",
    template = 
    """
    <key>BGTaskSchedulerPermittedIdentifiers</key>
    <array>
        <string>{telegram_bundle_id}.refresh</string>
    </array>
    <key>CFBundleAllowMixedLocalizations</key>
    <true/>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>Telegram</string>
    <key>CFBundleIdentifier</key>
    <string>{telegram_bundle_id}</string>
    <key>CFBundleName</key>
    <string>Telegram</string>
    <key>ITSAppUsesNonExemptEncryption</key>
    <false/>
    <key>LSApplicationQueriesSchemes</key>
    <array>
        <string>instagram</string>
        <string>comgooglemaps-x-callback</string>
        <string>foursquare</string>
        <string>here-location</string>
        <string>yandexmaps</string>
        <string>yandexnavi</string>
        <string>comgooglemaps</string>
        <string>youtube</string>
        <string>twitter</string>
        <string>vk</string>
        <string>waze</string>
        <string>googlechrome</string>
        <string>firefox</string>
        <string>touch-http</string>
        <string>yandexbrowser-open-url</string>
        <string>vimeo</string>
        <string>vine</string>
        <string>coub</string>
        <string>uber</string>
        <string>citymapper</string>
        <string>lyft</string>
        <string>opera-http</string>
        <string>firefox-focus</string>
        <string>ddgQuickLink</string>
        <string>moovit</string>
        <string>alook</string>
        <string>dgis</string>
        <string>microsoft-edge-http</string>
        <string>brave</string>
        <string>onionhttp</string>
        <string>ucbrowser</string>
        <string>dolphin</string>
    </array>
    <key>LSRequiresIPhoneOS</key>
    <true/>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key>
        <true/>
    </dict>
    <key>NSCameraUsageDescription</key>
    <string>We need this so that you can take and share photos and videos.</string>
    <key>NSContactsUsageDescription</key>
    <string>Telegram stores your contacts heavily encrypted in the cloud to let you connect with your friends across all your devices.</string>
    <key>NSFaceIDUsageDescription</key>
    <string>You can use Face ID to unlock the app.</string>
    <key>NSLocationAlwaysUsageDescription</key>
    <string>When you send your location to your friends, Telegram needs access to show them a map. You also need this to send locations from an Apple Watch.</string>
    <key>NSLocationWhenInUseUsageDescription</key>
    <string>When you send your location to your friends, Telegram needs access to show them a map.</string>
    <key>NSMicrophoneUsageDescription</key>
    <string>We need this so that you can record and share voice messages and videos with sound.</string>
    <key>NSMotionUsageDescription</key>
    <string>When you send your location to your friends, Telegram needs access to show them a map.</string>
    <key>NSPhotoLibraryAddUsageDescription</key>
    <string>We need this so that you can share photos and videos from your photo library.</string>
    <key>NSPhotoLibraryUsageDescription</key>
    <string>We need this so that you can share photos and videos from your photo library.</string>
    <key>NSSiriUsageDescription</key>
    <string>You can use Siri to send messages.</string>
    <key>NSUserActivityTypes</key>
    <array>
        <string>INSendMessageIntent</string>
        <string>RemindAboutChatIntent</string>
    </array>
    <key>UIAppFonts</key>
    <array>
        <string>SFCompactRounded-Semibold.otf</string>
    </array>
    <key>UIBackgroundModes</key>
    <array>
        <string>audio</string>
        <string>fetch</string>
        <string>location</string>
        <string>remote-notification</string>
        <string>voip</string>
    </array>
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
    <key>UTImportedTypeDeclarations</key>
    <array>
        <dict>
            <key>UTTypeConformsTo</key>
            <array>
                <string>public.data</string>
            </array>
            <key>UTTypeDescription</key>
            <string>Telegram iOS Color Theme File</string>
            <key>UTTypeIconFiles</key>
            <array>
                <string>BlueIcon@3x.png</string>
            </array>
            <key>UTTypeIdentifier</key>
            <string>org.telegram.Telegram-iOS.theme</string>
            <key>UTTypeTagSpecification</key>
            <dict>
                <key>public.filename-extension</key>
                <array>
                    <string>tgios-theme</string>
                </array>
            </dict>
        </dict>
    </array>
    """.format(
        telegram_bundle_id = telegram_bundle_id,
    )
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
        ":TelegramInfoPlist",
        ":AdditionalInfoPlist",
    ],
    app_icons = [
        ":DefaultAppIcon",
    ],
    frameworks = [
        ":TelegramUIFramework",
    ],
    strings = [
        ":AppStringResources",
    ],
    extensions = [
        #":ShareExtension",
        #":NotificationServiceExtension",
    ],
    #watch_application = ":TelegramWatchApp",
    deps = [
        ":Main",
        ":Lib",
    ],
)
