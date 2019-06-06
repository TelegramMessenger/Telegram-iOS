load('//tools:buck_utils.bzl', 'config_with_updated_linker_flags', 'configs_with_config', 'glob_sub_map')
load('//tools:buck_defs.bzl', 'SHARED_CONFIGS')

genrule(
    name = 'webp_lib_file',
    srcs = [
        'lib/libwebp.a',
    ],
    bash = 'mkdir -p $OUT; cp $SRCS $OUT/',
    out = 'webp_lib_file',
    visibility = [
        '//submodules/webp:...',
    ]
)

apple_library(
    name = 'webp_lib',
    visibility = [
        '//submodules/webp:...'
    ],
    header_namespace = 'webp',
    exported_headers = glob_sub_map('include/', glob([
        'include/**/*.h',
    ])),
    exported_linker_flags = [
        '-lwebp',
        '-L$(location :webp_lib_file)',
    ],
)

apple_library(
    name = 'WebP',
    srcs = glob([
        'WebP/*.m',
    ]),
    headers = glob([
        'WebP/*.h',
    ], exclude = ['WebP/WebP.h']),
    header_namespace = 'WebP',
    exported_headers = glob([
        'WebP/*.h',
    ], exclude = ['WebP/WebP.h']),
    modular = True,
    configs = configs_with_config({}),
    compiler_flags = ['-w'],
    preprocessor_flags = ['-fobjc-arc'],
    visibility = ['PUBLIC'],
    deps = [
        ':webp_lib',
    ],
    frameworks = [
        '$SDKROOT/System/Library/Frameworks/Foundation.framework',
        '$SDKROOT/System/Library/Frameworks/UIKit.framework',
    ],
)
