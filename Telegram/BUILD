load("@build_bazel_rules_apple//apple:ios.bzl",
    "ios_application",
    "ios_framework",
)

load("@build_bazel_rules_swift//swift:swift.bzl",
    "swift_library",
)

load("//build-system:defines.bzl",
    "file_from_define",
)

load(":telegram_info_plist.bzl",
    "telegram_info_plist",
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
        "Telegram-iOS/Icons.xcassets",
    ]),
)

filegroup(
    name = "AppIcons",
    srcs = glob([
        "Telegram-iOS/AppIcons.xcassets",
    ]),
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
        ":AppStringResources",
    ],
    deps = [
        "//submodules/GZip:GZip",
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/SSignalKit/SSignalKit:SSignalKit",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/ObjCRuntimeUtils:ObjCRuntimeUtils",
        "//submodules/UIKitRuntimeUtils:UIKitRuntimeUtils",
        "//submodules/Display:Display",
        "//submodules/AlertUI:AlertUI",
        "//submodules/ActivityIndicator:ActivityIndicator",
        "//submodules/OverlayStatusController:OverlayStatusController",
        "//submodules/openssl:openssl",
        "//submodules/OpenSSLEncryptionProvider:OpenSSLEncryptionProvider",
        "//submodules/WalletCore:WalletCore",
        "//submodules/BuildConfig:BuildConfig",
        "//submodules/AppBundle:AppBundle",
        "//submodules/SolidRoundedButtonNode:SolidRoundedButtonNode",
        "//submodules/Camera:Camera",
        "//submodules/QrCode:QrCode",
        "//submodules/MergeLists:MergeLists",
        "//submodules/GlassButtonNode:GlassButtonNode",
        "//submodules/UrlEscaping:UrlEscaping",
        "//submodules/LocalAuth:LocalAuth",
        "//submodules/ScreenCaptureDetection:ScreenCaptureDetection",
        "//submodules/WalletUrl:WalletUrl",
        "//submodules/ProgressNavigationButtonNode:ProgressNavigationButtonNode",
        "//submodules/Markdown:Markdown",
        "//submodules/StringPluralization:StringPluralization",
        "//submodules/YuvConversion:YuvConversion",
        "//submodules/rlottie:RLottieBinding",
        "//submodules/AnimatedStickerNode:AnimatedStickerNode",
        "//submodules/WalletUI:WalletUI",
        "//submodules/WebsiteType:WebsiteType",
        "//submodules/MtProtoKit:MtProtoKit",
        "//submodules/Postbox:Postbox",
        "//submodules/SyncCore:SyncCore",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/AccountContext:AccountContext",
        "//submodules/lottie-ios:Lottie",
        "//submodules/ChatListUI:ChatListUI",
    ],
)

additional_info_plist = telegram_info_plist(
    name = "AdditionalInfoPlist",
    app_name = "Telegram",
    url_scheme = "tg",
    bundle_id_define = "telegram_bundle_id",
    app_version_define = "telegram_version",
    build_number_define = "telegram_build_number",
)

ios_application(
    name = "Telegram",
    bundle_id = "{telegram_bundle_id}",
    families = ["iphone", "ipad"],
    minimum_os_version = "9.0",
    provisioning_profile = "//build-input/data/provisioning-profiles:App.mobileprovision",
    infoplists = [
        "Info.plist",
        ":AdditionalInfoPlist",
    ],
    frameworks = [
        #":AsyncDisplayKitFramework",
    ],
    deps = [
        ":Main",
        ":Lib",
    ],
)
