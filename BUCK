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

apple_binary(
    name = 'AppBinary',
    configs = configs_with_config(config_with_updated_linker_flags(APP_CONFIGS, ALL_LOAD_LINKER_FLAG)),
    swift_version = '4.2',
    srcs = [
        'Telegram-iOS/TempRoot.swift',
        'Telegram-iOS/TempMain.m',
    ],
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
    ],
)

apple_bundle(
    name = 'AppBundle',
    extension = 'app',
    binary = ':AppBinary',
    product_name = 'Telegram',
    info_plist = 'Info.plist',
    info_plist_substitutions = {
        'DEVELOPMENT_LANGUAGE': 'en-us',
        'EXECUTABLE_NAME': 'TelegramApp',
        'PRODUCT_BUNDLE_IDENTIFIER': 'ph.telegra.Telegraph',
        'PRODUCT_NAME': 'TelegramApp',
        'VERSION': '5.8',
        'BUILD_NUMBER': '2001',
    },
)

apple_package(
    name = 'AppPackage',
    bundle = ':AppBundle',
)
