load('//tools:buck_utils.bzl', 'config_with_updated_linker_flags', 'configs_with_config', 'merge_maps', 'glob_map', 'glob_sub_map', 'combined_config')
load('//tools:buck_defs.bzl', 'SHARED_CONFIGS', 'EXTENSION_LIB_SPECIFIC_CONFIG')

apple_library(
    name = 'TelegramUIPrivateModule',
    srcs = glob([
        'TelegramUI/**/*.m',
        'TelegramUI/**/*.mm',
        'TelegramUI/**/*.c',
        'TelegramUI/**/*.cpp',
        'third-party/opusenc/*.c',
        'third-party/opusenc/*.m',
        'third-party/opusfile/*.c',
        'third-party/ogg/ogg/*.c',
        'third-party/RMIntro/3rdparty/*.h',
        'third-party/RMIntro/core/*.c',
        'third-party/RMIntro/platform/common/*.c',
        'third-party/RMIntro/platform/ios/RMGeometry.m',
        'third-party/RMIntro/platform/ios/RMIntroPageView.m',
        'third-party/RMIntro/platform/ios/RMIntroViewController.m',
        'third-party/RMIntro/platform/ios/RMLoginViewController.m',
        'third-party/RMIntro/platform/ios/RMIntroViewController.m',
        'third-party/RMIntro/platform/ios/texture_helper.m',
    ]),
    headers = merge_maps([
        glob_map(glob([
            'TelegramUI/**/*.h',
            'third-party/opusenc/*.h',
            'third-party/opusfile/*.h',
            'third-party/RMIntro/3rdparty/**/*.h',
            'third-party/RMIntro/core/*.h',
            'third-party/RMIntro/platform/common/*.h',
            'third-party/RMIntro/platform/ios/platform_gl.h',
            'third-party/RMIntro/platform/ios/RMGeometry.h',
            'third-party/RMIntro/platform/ios/RMIntroPageView.h',
            'third-party/RMIntro/platform/ios/RMIntroViewController.h',
            'third-party/RMIntro/platform/ios/RMLoginViewController.h',
            'third-party/RMIntro/platform/ios/texture_helper.h',
        ])),
        glob_sub_map('third-party/ogg/', [
            'third-party/ogg/**/*.h',
        ]),
    ]),
    header_namespace = 'TelegramUIPrivateModule',
    exported_headers = [
        'third-party/opusenc/opusenc.h',
        'TelegramUI/TGDataItem.h',
        'TelegramUI/FastBlur.h',
        'TelegramUI/RingBuffer.h',
        'TelegramUI/TelegramUIIncludes.h',
        'third-party/RMIntro/platform/ios/RMIntroViewController.h',
        'TelegramUI/STPPaymentCardTextField.h',
        'TelegramUI/STPAPIClient.h',
        'TelegramUI/STPAPIClient+ApplePay.h',
        'TelegramUI/STPPaymentConfiguration.h',
        'TelegramUI/STPCard.h',
        'TelegramUI/STPToken.h',
        'TelegramUI/STPBlocks.h',
        'TelegramUI/STPCardBrand.h',
        'TelegramUI/STPCardParams.h',
        'TelegramUI/STPCustomer.h',
        'TelegramUI/STPFormEncoder.h',
        'TelegramUI/STPFormEncodable.h',
        'TelegramUI/STPAddress.h',
        'TelegramUI/STPAPIResponseDecodable.h',
        'TelegramUI/STPPaymentMethod.h',
        'TelegramUI/STPSource.h',
        'TelegramUI/STPBackendAPIAdapter.h',
        'TelegramUI/OngoingCallThreadLocalContext.h',
        'TelegramUI/SecretChatKeyVisualization.h',
        'TelegramUI/NumberPluralizationForm.h',
        'TelegramUI/DeviceProximityManager.h',
        'TelegramUI/RaiseToListenActivator.h',
        'TelegramUI/TGMimeTypeMap.h',
        'TelegramUI/TGEmojiSuggestions.h',
        'TelegramUI/TGChannelIntroController.h',
        'TelegramUI/EDSunriseSet.h',
        'TelegramUI/TGBridgeAudioDecoder.h',
        'TelegramUI/TGBridgeAudioEncoder.h',
        'TelegramUI/GZip.h',
    ],
    modular = True,
    #visibility = ['//submodules/TelegramUI:TelegramUI'],
    visibility = ['PUBLIC'],
    deps = [
        '//submodules/SSignalKit:SSignalKit',
        '//submodules/LegacyComponents:LegacyComponents',
        '//submodules/ffmpeg:opus',
        '//submodules/MtProtoKit:MtProtoKit',
    ],
)

apple_resource(
    name = "TelegramUIResources",
    files = glob([
        "TelegramUI/Resources/**/*",
    ]),
)

apple_asset_catalog(
    name = 'Images',
    dirs = [
        'Images.xcassets',
    ],
)

apple_library(
    name = 'TelegramUI',
    srcs = glob([
	    'TelegramUI/**/*.swift'
    ]),
	configs = configs_with_config(combined_config([SHARED_CONFIGS, EXTENSION_LIB_SPECIFIC_CONFIG])),
	#swift_compiler_flags = [
    #    '-application-extension',
    #],
    visibility = ['PUBLIC'],
    deps = [
        ':TelegramUIResources',
        ':Images',
        ':TelegramUIPrivateModule#static',
    	'//submodules/SSignalKit:SwiftSignalKit#static',
        '//submodules/SSignalKit:SSignalKit#static',
    	'//submodules/Postbox:Postbox#static',
    	'//submodules/TelegramCore:TelegramCore#static',
    	'//submodules/MtProtoKit:MtProtoKit#static',
        '//submodules/ffmpeg:FFMpeg#static',
        '//submodules/AsyncDisplayKit:AsyncDisplayKit#static',
        '//submodules/Display:Display#static',
        '//submodules/LegacyComponents:LegacyComponents#static',
        '//submodules/lottie-ios:Lottie#static',
        '//submodules/webp:WebPImage#static',
    ],
)

apple_bundle(
    name = "TelegramUIFramework",
    extension = "framework",
    binary = ":TelegramUI#shared",
    info_plist = 'TelegramUI/Info.plist',
    info_plist_substitutions = {
        'DEVELOPMENT_LANGUAGE': 'en-us',
        'APP_NAME': 'Telegram',
        'EXECUTABLE_NAME': 'TelegramUI',
        'PRODUCT_BUNDLE_IDENTIFIER': 'org.telegram.TelegramUI',
        'PRODUCT_NAME': 'Telegram UI',
        'CURRENT_PROJECT_VERSION': '5.8',
    },
    visibility = ['PUBLIC'],
)
