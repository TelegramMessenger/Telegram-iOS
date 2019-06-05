load('//tools:buck_utils.bzl', 'config_with_updated_linker_flags', 'configs_with_config')
load('//tools:buck_defs.bzl', 'combined_config', 'SHARED_CONFIGS', 'LIB_SPECIFIC_CONFIG')

apple_library(
    name = 'Lottie',
    srcs = glob([
        'lottie-ios/Classes/**/*.m',
    ]),
    headers = glob([
        'lottie-ios/Classes/**/*.h',
    ]),
    header_namespace = 'HockeySDK',
    exported_headers = glob([
        'lottie-ios/Classes/PublicHeaders/*.h'
    ]),
    modular = True,
    configs = configs_with_config(combined_config([SHARED_CONFIGS, LIB_SPECIFIC_CONFIG])),
    compiler_flags = [
        '-w'
    ],
    preprocessor_flags = ['-fobjc-arc'],
    visibility = ['PUBLIC'],
    deps = [
    ],
    frameworks = [
        '$SDKROOT/System/Library/Frameworks/Foundation.framework',
        '$SDKROOT/System/Library/Frameworks/UIKit.framework',
    ],
)
