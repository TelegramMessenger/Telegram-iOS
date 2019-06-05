load('//tools:buck_utils.bzl', 'config_with_updated_linker_flags', 'configs_with_config')
load('//tools:buck_defs.bzl', 'combined_config', 'SHARED_CONFIGS', 'LIB_SPECIFIC_CONFIG')

apple_library(
	name = 'TelegramCorePrivateModule',
	srcs = glob([
		'TelegramCore/**/*.m',
		'TelegramCore/**/*.c',
		'third-party/libphonenumber-iOS/*.m',
	]),
	headers = glob([
		'TelegramCore/**/*.h',
		'third-party/libphonenumber-iOS/*.h',
	]),
	header_namespace = 'TelegramCorePrivateModule',
	exported_headers = glob([
		'TelegramCore/**/*.h',
		'third-party/libphonenumber-iOS/*.h',
	], exclude = ['TelegramCore/TelegramCore.h']),
	modular = True,
	visibility = ['//submodules/TelegramCore:TelegramCore'],
	deps = [
		'//submodules/MtProtoKit:MtProtoKit',
	],
)

apple_library(
    name = 'TelegramCore',
    srcs = glob([
	    'TelegramCore/**/*.swift'
    ]),
	configs = configs_with_config(combined_config([SHARED_CONFIGS, LIB_SPECIFIC_CONFIG])),
	swift_compiler_flags = [
        '-suppress-warnings',
        '-application-extension',
    ],
    visibility = ['PUBLIC'],
    deps = [
    	':TelegramCorePrivateModule',
    	'//submodules/SSignalKit:SwiftSignalKit',
    	'//submodules/MtProtoKit:MtProtoKit',
    	'//submodules/Postbox:Postbox',
    ],
)
