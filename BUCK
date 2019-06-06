load('//tools:buck_utils.bzl', 'config_with_updated_linker_flags', 'configs_with_config', 'glob_map', 'merge_maps', 'glob_sub_map')
load('//tools:buck_defs.bzl', 'combined_config', 'SHARED_CONFIGS', 'LIB_SPECIFIC_CONFIG')

apple_library(
    name = 'tgvoip',
    srcs = glob([
        '*.m',
        '*.cpp',
        'audio/*.cpp',
        'video/*.cpp',
        'os/darwin/*.m',
        'os/darwin/*.mm',
        'os/darwin/*.cpp',
        'os/posix/*.cpp',
        'webrtc_dsp/**/*.c',
        'webrtc_dsp/**/*.cc',
        'webrtc_dsp/**/*.cpp',
    ], exclude = ['os/darwin/*OSX*']),
    headers = merge_maps([
        glob_map(glob([
            '*.h',
            'audio/*.h',
            'video/*.h',
        ])),
        glob_map(glob([
            'os/darwin/*.h',
        ], exclude = ['os/darwin/*OSX*'])),
        glob_sub_map('webrtc_dsp/', [
            'webrtc_dsp/**/*.h',
        ]),
    ]),
    header_namespace = 'tgvoip',
    exported_headers = glob([
        '*.h'
    ]),
    modular = True,
    configs = configs_with_config(combined_config([SHARED_CONFIGS, LIB_SPECIFIC_CONFIG])),
    compiler_flags = [
        '-w',
        '-DTGVOIP_USE_CUSTOM_CRYPTO',
        '-DWEBRTC_APM_DEBUG_DUMP=0',
        '-DWEBRTC_POSIX',
        '-DTGVOIP_HAVE_TGLOG',
        '-DWEBRTC_NS_FLOAT',
        '-DWEBRTC_IOS',
        '-DWEBRTC_HAS_NEON',
    ],
    preprocessor_flags = ['-fobjc-arc'],
    visibility = ['PUBLIC'],
    deps = [
        '//submodules/ffmpeg:opus',
    ],
    frameworks = [
        '$SDKROOT/System/Library/Frameworks/Foundation.framework',
        '$SDKROOT/System/Library/Frameworks/UIKit.framework',
        '$SDKROOT/System/Library/Frameworks/AudioToolbox.framework',
        '$SDKROOT/System/Library/Frameworks/VideoToolbox.framework',
    ],
)
