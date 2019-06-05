load('//tools:buck_utils.bzl', 'config_with_updated_linker_flags', 'configs_with_config')
load('//tools:buck_defs.bzl', 'SHARED_CONFIGS')

apple_library(
    name = 'SwiftSignalKit',
    srcs = glob([
        'SwiftSignalKit/*.swift'
    ]),
    modular = True,
    configs = configs_with_config({}),
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
    headers = glob([
        'SSignalKit/*.h',
    ]),
    header_namespace = 'SSignalKit',
    exported_headers = glob([
        'SSignalKit/*.h',
    ]),
    modular = True,
    configs = configs_with_config({}),
    compiler_flags = ['-w'],
    preprocessor_flags = ['-fobjc-arc'],
    visibility = ['PUBLIC'],
    frameworks = [
        '$SDKROOT/System/Library/Frameworks/Foundation.framework',
    ],
)
