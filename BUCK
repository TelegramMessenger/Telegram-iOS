load('//tools:buck_utils.bzl', 'config_with_updated_linker_flags', 'configs_with_config')
load('//tools:buck_defs.bzl', 'combined_config', 'SHARED_CONFIGS', 'LIB_SPECIFIC_CONFIG')

apple_library(
    name = 'DisplayPrivate',
    srcs = glob([
        'Display/*.m',
    ]),
    headers = glob([
        'Display/*.h',
    ]),
    header_namespace = 'DisplayPrivate',
    exported_headers = glob([
        'Display/*.h',
    ], exclude = ['Display/Display.h']),
    modular = True,
    configs = configs_with_config(combined_config([SHARED_CONFIGS, LIB_SPECIFIC_CONFIG])),
    compiler_flags = ['-w'],
    preprocessor_flags = ['-fobjc-arc'],
    visibility = ['//submodules/Display:Display'],
    deps = [
        '//submodules/AsyncDisplayKit:AsyncDisplayKit',
    ],
    frameworks = [
        '$SDKROOT/System/Library/Frameworks/Foundation.framework',
        '$SDKROOT/System/Library/Frameworks/UIKit.framework',
    ],
)

apple_library(
    name = 'Display',
    srcs = glob([
	    'Display/*.swift',
    ]),
    configs = configs_with_config(combined_config([SHARED_CONFIGS, LIB_SPECIFIC_CONFIG])),
    swift_compiler_flags = [
        '-suppress-warnings',
        '-application-extension',
    ],
    visibility = ['PUBLIC'],
    deps = [
        ':DisplayPrivate',
        '//submodules/AsyncDisplayKit:AsyncDisplayKit',
        '//submodules/SSignalKit:SwiftSignalKit',
    ],
    frameworks = [
		'$SDKROOT/System/Library/Frameworks/Foundation.framework',
		'$SDKROOT/System/Library/Frameworks/UIKit.framework',
		'$SDKROOT/System/Library/Frameworks/QuartzCore.framework',
		'$SDKROOT/System/Library/Frameworks/CoreText.framework',
		'$SDKROOT/System/Library/Frameworks/CoreGraphics.framework',
    ],
)
