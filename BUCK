load('//tools:buck_utils.bzl', 'config_with_updated_linker_flags', 'configs_with_config', 'gen_header_targets', 'gen_lib_targets', 'lib_basename')
load('//tools:buck_defs.bzl', 'combined_config', 'SHARED_CONFIGS', 'LIB_SPECIFIC_CONFIG')

genrule(
    name = 'opus_lib',
    srcs = [
        'opus/lib/libopus.a',
    ],
    bash = 'mkdir -p $OUT; cp $SRCS $OUT/',
    out = 'opus_lib',
    visibility = [
        '//submodules/ffmpeg:opus',
    ]
)

apple_library(
    name = 'opus',
    visibility = [
        'PUBLIC',
    ],
    header_namespace = 'opus',
    exported_headers = glob([
        'opus/include/opus/*.h',
    ]),
    exported_linker_flags = [
        '-lopus',
        '-L$(location :opus_lib)',
    ],
)

ffmpeg_header_paths = [
    'libavutil/hwcontext.h',
    'libavutil/time.h',
    'libavutil/hwcontext_cuda.h',
    'libavutil/intfloat.h',
    'libavutil/error.h',
    'libavutil/fifo.h',
    'libavutil/blowfish.h',
    'libavutil/hwcontext_mediacodec.h',
    'libavutil/replaygain.h',
    'libavutil/version.h',
    'libavutil/murmur3.h',
    'libavutil/stereo3d.h',
    'libavutil/samplefmt.h',
    'libavutil/pixdesc.h',
    'libavutil/base64.h',
    'libavutil/rational.h',
    'libavutil/sha.h',
    'libavutil/motion_vector.h',
    'libavutil/avconfig.h',
    'libavutil/lfg.h',
    'libavutil/avutil.h',
    'libavutil/xtea.h',
    'libavutil/crc.h',
    'libavutil/hwcontext_vdpau.h',
    'libavutil/frame.h',
    'libavutil/file.h',
    'libavutil/md5.h',
    'libavutil/cast5.h',
    'libavutil/hwcontext_vaapi.h',
    'libavutil/spherical.h',
    'libavutil/ffversion.h',
    'libavutil/audio_fifo.h',
    'libavutil/tree.h',
    'libavutil/threadmessage.h',
    'libavutil/attributes.h',
    'libavutil/adler32.h',
    'libavutil/hwcontext_d3d11va.h',
    'libavutil/timecode.h',
    'libavutil/sha512.h',
    'libavutil/hwcontext_dxva2.h',
    'libavutil/display.h',
    'libavutil/buffer.h',
    'libavutil/camellia.h',
    'libavutil/pixelutils.h',
    'libavutil/hwcontext_drm.h',
    'libavutil/common.h',
    'libavutil/hmac.h',
    'libavutil/eval.h',
    'libavutil/dict.h',
    'libavutil/random_seed.h',
    'libavutil/opt.h',
    'libavutil/mastering_display_metadata.h',
    'libavutil/log.h',
    'libavutil/aes.h',
    'libavutil/macros.h',
    'libavutil/bswap.h',
    'libavutil/rc4.h',
    'libavutil/tea.h',
    'libavutil/cpu.h',
    'libavutil/lzo.h',
    'libavutil/des.h',
    'libavutil/channel_layout.h',
    'libavutil/encryption_info.h',
    'libavutil/twofish.h',
    'libavutil/imgutils.h',
    'libavutil/hwcontext_videotoolbox.h',
    'libavutil/mem.h',
    'libavutil/parseutils.h',
    'libavutil/ripemd.h',
    'libavutil/bprint.h',
    'libavutil/hwcontext_qsv.h',
    'libavutil/pixfmt.h',
    'libavutil/aes_ctr.h',
    'libavutil/timestamp.h',
    'libavutil/downmix_info.h',
    'libavutil/avassert.h',
    'libavutil/hash.h',
    'libavutil/mathematics.h',
    'libavutil/intreadwrite.h',
    'libavutil/avstring.h',
    'libavformat/version.h',
    'libavformat/avio.h',
    'libavformat/avformat.h',
    'libavcodec/adts_parser.h',
    'libavcodec/avcodec.h',
    'libavcodec/version.h',
    'libavcodec/vdpau.h',
    'libavcodec/qsv.h',
    'libavcodec/vaapi.h',
    'libavcodec/videotoolbox.h',
    'libavcodec/xvmc.h',
    'libavcodec/mediacodec.h',
    'libavcodec/d3d11va.h',
    'libavcodec/avfft.h',
    'libavcodec/jni.h',
    'libavcodec/dirac.h',
    'libavcodec/avdct.h',
    'libavcodec/ac3_parser.h',
    'libavcodec/vorbis_parser.h',
    'libavcodec/dxva2.h',
    'libavcodec/dv_profile.h',
    'libswresample/version.h',
    'libswresample/swresample.h',
]

ffmpeg_lib_paths = [
    'libavutil.a',
    'libavcodec.a',
    'libavformat.a',
    'libswresample.a',
]

genrule(
    name = 'libffmpeg_build',
    srcs = glob([
        "FFMpeg/**/*",
    ]),
    bash = '$SRCDIR/FFMpeg/build-ffmpeg.sh debug x86_64 $OUT $SRCDIR/FFMpeg',
    out = 'libffmpeg',
    visibility = [
        '//submodules/ffmpeg:FFMpeg',
        '//submodules/ffmpeg:libffmpeg',
    ]
)

ffmpeg_header_targets = gen_header_targets(ffmpeg_header_paths, 'ffmpeg_header_', 'libffmpeg_build', 'FFmpeg-iOS/include')
ffmpeg_lib_targets = gen_lib_targets(ffmpeg_lib_paths, 'ffmpeg_lib_', 'libffmpeg_build', 'FFmpeg-iOS/lib')

ffmpeg_lib_targets_flags = [ '-l' + lib_basename(name) for name in ffmpeg_lib_targets ]
ffmpeg_lib_targets_flags.append('-L$(location :libffmpeg_build)/FFmpeg-iOS/lib')
ffmpeg_lib_targets_flags.append('-lbz2')
ffmpeg_lib_targets_flags.append('-liconv')

apple_library(
    name = 'libffmpeg',
    visibility = [
        '//submodules/ffmpeg:FFMpeg'
    ],
    header_namespace = 'ffmpeg',
    exported_headers = ffmpeg_header_targets,
    exported_linker_flags = ffmpeg_lib_targets_flags,
    deps = [
        ':libffmpeg_build'
    ],
)

apple_library(
    name = "FFMpeg",
    srcs = glob([
        "FFMpeg/*.m",
    ]),
    header_namespace = 'FFMpeg',
    headers = ffmpeg_header_targets,
    exported_headers = glob([
        "FFMpeg/*.h",
    ]),
    modular = True,
    swift_compiler_flags = ['-suppress-warnings'],
    visibility = ["PUBLIC"],
    deps = [
        ':libffmpeg_build',
        ':libffmpeg',
    ],
    frameworks = [
        '$SDKROOT/System/Library/Frameworks/Foundation.framework',
        '$SDKROOT/System/Library/Frameworks/UIKit.framework',
        '$SDKROOT/System/Library/Frameworks/CoreMedia.framework',
    ],
)
