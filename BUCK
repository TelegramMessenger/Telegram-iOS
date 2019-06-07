load('//tools:buck_utils.bzl', 'config_with_updated_linker_flags', 'configs_with_config')
load('//tools:buck_defs.bzl', 'combined_config', 'SHARED_CONFIGS', 'LIB_SPECIFIC_CONFIG')

apple_library(
	name = 'sqlcipher',
	srcs = glob([
		'Postbox/**/*.m',
		'Postbox/**/*.c',
	]),
	headers = glob([
		'Postbox/**/*.h',
	]),
	header_namespace = 'sqlcipher',
	exported_headers = glob([
		'Postbox/**/*.h',
	], exclude = ['Postbox/Postbox.h']),
	compiler_flags = [
		'-DNDEBUG',
		'-DSQLCIPHER_CRYPTO_CC=1',
		'-DSQLITE_ENABLE_FTS5',
		'-DSQLITE_DEFAULT_MEMSTATUS=0',
		'-DSQLITE_MAX_MMAP_SIZE=0',
		'-DSQLITE_HAS_CODEC',
	],
	modular = True,
	visibility = ['//submodules/Postbox:Postbox'],
)

apple_library(
    name = 'Postbox',
    srcs = glob([
	    'Postbox/**/*.swift'
    ]),
	configs = configs_with_config(combined_config([SHARED_CONFIGS, LIB_SPECIFIC_CONFIG])),
	swift_compiler_flags = [
        '-suppress-warnings',
        '-application-extension',
    ],
    visibility = ['PUBLIC'],
    deps = [
    	':sqlcipher',
    	'//submodules/SSignalKit:SwiftSignalKit'
    ],
)
