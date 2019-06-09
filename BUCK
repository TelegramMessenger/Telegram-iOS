load('//tools:buck_utils.bzl', 'config_with_updated_linker_flags', 'configs_with_config')
load('//tools:buck_defs.bzl', 'SHARED_CONFIGS')

# Adding `-all_load` to our binaries works around https://bugs.swift.org/browse/SR-6004. See the
# longer comment in `ViewController.swift` for more details.
ALL_LOAD_LINKER_FLAG = '-all_load'

APP_CONFIGS = {
    'ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES': 'YES',
    'DEVELOPMENT_LANGUAGE': 'Swift',
    'PRODUCT_BUNDLE_IDENTIFIER': 'ph.telegra.Telegraph',
    'PROVISIONING_PROFILE_SPECIFIER': 'match Development ph.telegra.Telegraph',
    'TARGETED_DEVICE_FAMILY': '1,2',
}
APP_CONFIGS.update(SHARED_CONFIGS)

apple_resource(
    name = 'LaunchScreenXib',
    files = [
        'Telegram-iOS/Base.lproj/LaunchScreen.xib',
    ],
)

apple_asset_catalog(
    name = 'Images',
    dirs = [
        'Telegram-iOS/Images.xcassets',
    ],
    app_icon = 'AppIconLLC',
)

apple_library(
    name = 'BuildConfig',
    srcs = glob([
        'Telegram-iOS/BuildConfig.m',
    ]),
    headers = [
        'Telegram-iOS/BuildConfig.h',
    ],
    compiler_flags = [
        '-w',
        '-DAPP_CONFIG_IS_INTERNAL_BUILD=false',
        '-DAPP_CONFIG_IS_APPSTORE_BUILD=true',
        '-DAPP_CONFIG_APPSTORE_ID=686449807',
        '-DAPP_SPECIFIC_URL_SCHEME=\"tgapp\"',
        '-DAPP_CONFIG_API_ID=8',
        '-DAPP_CONFIG_API_HASH=\"7245de8e747a0d6fbe11f7cc14fcc0bb\"',
        '-DAPP_CONFIG_HOCKEYAPP_ID=\"ad8831329ffc8f8aff9a2b0b86558b24\"',
    ],
    header_namespace = 'BuildConfig',
    exported_headers = [
        'Telegram-iOS/BuildConfig.h',
    ],
    modular = True,
    visibility = ['PUBLIC'],
    deps = [
        '//submodules/MtProtoKit:MtProtoKit',
    ],
)

apple_library(
    name = 'AppBinaryPrivate',
    srcs = glob([
        'Telegram-iOS/TGBridgeServer.m',
        'Telegram-iOS/TGAutoDownloadPreferences.m',
        'Telegram-iOS/TGPresentationAutoNightPreferences.m',
        'Telegram-iOS/TGProxyItem.m',
        'Telegram-iOS/UIImage+ImageEffects.m',
    ]),
    headers = [
    ],
    header_namespace = 'AppBinaryPrivate',
    exported_headers = [
        'Telegram-iOS/TGBridgeServer.h',
        'Telegram-iOS/TGAutoDownloadPreferences.h',
        'Telegram-iOS/TGPresentationAutoNightPreferences.h',
        'Telegram-iOS/TGProxyItem.h',
        'Telegram-iOS/UIImage+ImageEffects.h',
    ],
    modular = True,
    #visibility = ['//submodules/TelegramUI:TelegramUI'],
    visibility = ['PUBLIC'],
    deps = [
        '//submodules/SSignalKit:SSignalKit',
        '//Watch:WatchUtils',
        '//submodules/LegacyComponents:LegacyComponents',
    ],
)

apple_binary(
    name = 'AppBinary',
    configs = configs_with_config(config_with_updated_linker_flags(APP_CONFIGS, ALL_LOAD_LINKER_FLAG)),
    srcs = glob([
        'Telegram-iOS/*.swift',
    ]) + [
        'Telegram-iOS/main.m',
    ],
    entitlements_file = 'Telegram-iOS/Telegram-iOS-AppStoreLLC.entitlements',
    deps = [
        ':LaunchScreenXib',
        ':Images',
        '//submodules/AsyncDisplayKit:AsyncDisplayKit',
        '//submodules/MtProtoKit:MtProtoKit',
        '//submodules/SSignalKit:SwiftSignalKit',
        '//submodules/SSignalKit:SSignalKit',
        '//submodules/Display:Display',
        '//submodules/Postbox:Postbox',
        '//submodules/TelegramCore:TelegramCore',
        '//submodules/LegacyComponents:LegacyComponents',
        '//submodules/HockeySDK-iOS:HockeySDK',
        '//submodules/lottie-ios:Lottie',
        '//submodules/libtgvoip:tgvoip',
        '//submodules/webp:WebP',
        '//submodules/ffmpeg:FFMpeg',
        '//submodules/TelegramUI:TelegramUI',
        '//submodules/TelegramUI:TelegramUIPrivateModule',
        '//Watch:WatchUtils',
        ':BuildConfig',
        ':AppBinaryPrivate',
    ],
)

xcode_workspace_config(
    name = "workspace",
    workspace_name = "Telegram",
    src_target = ":AppBinary",
)

apple_bundle(
    name = 'AppBundle',
    extension = 'app',
    binary = ':AppBinary',
    product_name = 'Telegram',
    info_plist = 'Telegram-iOS/Info.plist',
    info_plist_substitutions = {
        'DEVELOPMENT_LANGUAGE': 'en-us',
        'APP_NAME': 'Telegram',
        'EXECUTABLE_NAME': 'Telegram',
        'PRODUCT_BUNDLE_IDENTIFIER': 'ph.telegra.Telegraph',
        'PRODUCT_NAME': 'Telegram',
        'APP_SPECIFIC_URL_SCHEME': 'tgapp',
        'VERSION': '5.8',
        'BUILD_NUMBER': '2001',
    },
)

apple_package(
    name = 'AppPackage',
    bundle = ':AppBundle',
)
