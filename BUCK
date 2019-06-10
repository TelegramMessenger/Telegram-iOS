load('//tools:buck_utils.bzl', 'config_with_updated_linker_flags', 'configs_with_config', 'combined_config')
load('//tools:buck_defs.bzl', 'SHARED_CONFIGS', 'EXTENSION_LIB_SPECIFIC_CONFIG')

apple_library(
    name = 'SwiftSignalKit',
    srcs = glob([
        'SwiftSignalKit/*.swift'
    ]),
    configs = configs_with_config(combined_config([SHARED_CONFIGS, EXTENSION_LIB_SPECIFIC_CONFIG])),
    modular = True,
    visibility = ['PUBLIC'],
    frameworks = [
        '$SDKROOT/System/Library/Frameworks/Foundation.framework',
    ],
)

apple_library(
    name = 'SSignalKit',
    srcs = glob([
        'SSignalKit/*.m',
    ]),
    configs = configs_with_config(combined_config([SHARED_CONFIGS, EXTENSION_LIB_SPECIFIC_CONFIG])),
    headers = glob([
        'SSignalKit/*.h',
    ]),
    header_namespace = 'SSignalKit',
    exported_headers = glob([
        'SSignalKit/*.h',
    ]),
    modular = True,
    compiler_flags = ['-w'],
    preprocessor_flags = ['-fobjc-arc'],
    visibility = ['PUBLIC'],
    frameworks = [
        '$SDKROOT/System/Library/Frameworks/Foundation.framework',
    ],
)
