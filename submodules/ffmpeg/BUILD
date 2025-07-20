
ffmpeg_header_paths = [
    "libavutil/hwcontext.h",
    "libavutil/time.h",
    "libavutil/iamf.h",
    "libavutil/intfloat.h",
    "libavutil/error.h",
    "libavutil/detection_bbox.h",
    "libavutil/ambient_viewing_environment.h",
    "libavutil/fifo.h",
    "libavutil/blowfish.h",
    "libavutil/replaygain.h",
    "libavutil/version.h",
    "libavutil/murmur3.h",
    "libavutil/stereo3d.h",
    "libavutil/samplefmt.h",
    "libavutil/pixdesc.h",
    "libavutil/base64.h",
    "libavutil/rational.h",
    "libavutil/sha.h",
    "libavutil/motion_vector.h",
    "libavutil/uuid.h",
    "libavutil/avconfig.h",
    "libavutil/lfg.h",
    "libavutil/avutil.h",
    "libavutil/xtea.h",
    "libavutil/crc.h",
    "libavutil/frame.h",
    "libavutil/file.h",
    "libavutil/md5.h",
    "libavutil/cast5.h",
    "libavutil/spherical.h",
    "libavutil/ffversion.h",
    "libavutil/audio_fifo.h",
    "libavutil/tree.h",
    "libavutil/threadmessage.h",
    "libavutil/attributes.h",
    "libavutil/hdr_dynamic_vivid_metadata.h",
    "libavutil/adler32.h",
    "libavutil/timecode.h",
    "libavutil/dovi_meta.h",
    "libavutil/tx.h",
    "libavutil/sha512.h",
    "libavutil/display.h",
    "libavutil/buffer.h",
    "libavutil/camellia.h",
    "libavutil/csp.h",
    "libavutil/video_hint.h",
    "libavutil/pixelutils.h",
    "libavutil/common.h",
    "libavutil/hmac.h",
    "libavutil/eval.h",
    "libavutil/executor.h",
    "libavutil/dict.h",
    "libavutil/random_seed.h",
    "libavutil/opt.h",
    "libavutil/mastering_display_metadata.h",
    "libavutil/log.h",
    "libavutil/aes.h",
    "libavutil/macros.h",
    "libavutil/bswap.h",
    "libavutil/rc4.h",
    "libavutil/tea.h",
    "libavutil/cpu.h",
    "libavutil/lzo.h",
    "libavutil/des.h",
    "libavutil/channel_layout.h",
    "libavutil/encryption_info.h",
    "libavutil/twofish.h",
    "libavutil/imgutils.h",
    "libavutil/hwcontext_videotoolbox.h",
    "libavutil/video_enc_params.h",
    "libavutil/mem.h",
    "libavutil/parseutils.h",
    "libavutil/ripemd.h",
    "libavutil/bprint.h",
    "libavutil/hdr_dynamic_metadata.h",
    "libavutil/pixfmt.h",
    "libavutil/aes_ctr.h",
    "libavutil/timestamp.h",
    "libavutil/downmix_info.h",
    "libavutil/avassert.h",
    "libavutil/hash.h",
    "libavutil/mathematics.h",
    "libavutil/intreadwrite.h",
    "libavutil/film_grain_params.h",
    "libavutil/avstring.h",
    "libavformat/version.h",
    "libavformat/version_major.h",
    "libavformat/avio.h",
    "libavformat/avformat.h",
    "libavcodec/adts_parser.h",
    "libavcodec/avcodec.h",
    "libavcodec/defs.h",
    "libavcodec/version.h",
    "libavcodec/codec_par.h",
    "libavcodec/codec_desc.h",
    "libavcodec/videotoolbox.h",
    "libavcodec/avfft.h",
    "libavcodec/codec.h",
    "libavcodec/packet.h",
    "libavcodec/version_major.h",
    "libavcodec/bsf.h",
    "libavcodec/codec_id.h",
    "libavcodec/dirac.h",
    "libavcodec/avdct.h",
    "libavcodec/ac3_parser.h",
    "libavcodec/vorbis_parser.h",
    "libavcodec/dv_profile.h",
    "libswresample/version.h",
    "libswresample/version_major.h",
    "libswresample/swresample.h",
]

ffmpeg_libs = [
    "libavutil.a",
    "libavcodec.a",
    "libavformat.a",
    "libswresample.a",
]

source_files = glob([
    "Sources/**/*",
], exclude = ["Sources/**/.*"])

filegroup(
    name = "FFMpegSources",
    srcs = source_files,
)

vpx_headers = [
    "vp8.h",
    "vp8cx.h",
    "vp8dx.h",
    "vpx_codec.h",
    "vpx_decoder.h",
    "vpx_encoder.h",
    "vpx_frame_buffer.h",
    "vpx_image.h",
    "vpx_integer.h",
    "vpx_version.h",
    "vpx_ext_ratectrl.h",
    "vpx_tpl.h",
]

vpx_libs = [
    "VPX",
]

opus_headers = [
    "opus.h",
    "opus_defines.h",
    "opus_multistream.h",
    "opus_projection.h",
    "opus_types.h",
]

opus_libs = [
    "opus",
]

dav1d_headers = [
    "compat/msvc/stdatomic.h",
    "compat/gcc/stdatomic.h",
    "compat/getopt.h",
    "common/dump.h",
    "common/frame.h",
    "common/bitdepth.h",
    "common/attributes.h",
    "common/validate.h",
    "common/intops.h",
    "dav1d/picture.h",
    "dav1d/version.h",
    "dav1d/data.h",
    "dav1d/headers.h",
    "dav1d/common.h",
    "dav1d/dav1d.h",
]

dav1d_libs = [
    "dav1d",
]

genrule(
    name = "libffmpeg_build",
    srcs = [
        ":FFMpegSources"
    ] + [
        "//third-party/libvpx:Public/vpx/{}".format(x) for x in vpx_headers
    ] + [
        "//third-party/libvpx:Public/vpx/lib{}.a".format(x) for x in vpx_libs
    ] + [
        "//third-party/opus:Public/opus/{}".format(x) for x in opus_headers
    ] + [
        "//third-party/opus:Public/opus/lib/lib{}.a".format(x) for x in opus_libs
    ] + [
        "//third-party/dav1d:Public/{}".format(x) for x in dav1d_headers
    ] + [
        "//third-party/dav1d:Public/dav1d/lib/lib{}.a".format(x) for x in dav1d_libs
    ],
    cmd_bash =
    """
        set -x

        ABS_RULEDIR="$$(pwd)/$(RULEDIR)"
        echo "ABS_RULEDIR=$$ABS_RULEDIR"

        SOURCE_PATH="$$ABS_RULEDIR/FFMpegSource"
        rm -rf "$$SOURCE_PATH"

        cp -R "submodules/ffmpeg/Sources/FFMpeg" "$$SOURCE_PATH"

        mkdir "$$SOURCE_PATH/libvpx"
        mkdir -p "$$SOURCE_PATH/libvpx/include/vpx"
        mkdir -p "$$SOURCE_PATH/libvpx/lib"
    """ +
        "\n" +
        "\n".join([
            "cp $(location //third-party/libvpx:Public/vpx/{}) $$SOURCE_PATH/libvpx/include/vpx/".format(x) for x in vpx_headers
        ]) +
        "\n" +
        "\n".join([
            "cp $(location //third-party/libvpx:Public/vpx/libVPX.a) $$SOURCE_PATH/libvpx/lib/".format(x) for x in vpx_libs
        ]) +
        "\n" +
    """
    
        mkdir "$$SOURCE_PATH/libopus"
        mkdir -p "$$SOURCE_PATH/libopus/include/opus"
        mkdir -p "$$SOURCE_PATH/libopus/lib"
    """ + 
        "\n" +
        "\n".join([
            "cp $(location //third-party/opus:Public/opus/{}) $$SOURCE_PATH/libopus/include/opus/".format(x) for x in opus_headers
        ]) +
        "\n" +
        "\n".join([
            "cp $(location //third-party/opus:Public/opus/lib/lib{}.a) $$SOURCE_PATH/libopus/lib/".format(x) for x in opus_libs
        ]) +
        "\n" +
    """
        mkdir "$$SOURCE_PATH/libdav1d"
        mkdir -p "$$SOURCE_PATH/libdav1d/include"
        mkdir -p "$$SOURCE_PATH/libdav1d/include/compat"
        mkdir -p "$$SOURCE_PATH/libdav1d/include/compat/msvc"
        mkdir -p "$$SOURCE_PATH/libdav1d/include/compat/gcc"
        mkdir -p "$$SOURCE_PATH/libdav1d/include/common"
        mkdir -p "$$SOURCE_PATH/libdav1d/include/dav1d"
        mkdir -p "$$SOURCE_PATH/libdav1d/lib"
    """ + 
    "\n" +
        "\n".join([
            "cp $(location //third-party/dav1d:Public/{}) $$SOURCE_PATH/libdav1d/include/{}".format(x, x) for x in dav1d_headers
        ]) +
        "\n" +
        "\n".join([
            "cp $(location //third-party/dav1d:Public/dav1d/lib/lib{}.a) $$SOURCE_PATH/libdav1d/lib/".format(x) for x in dav1d_libs
        ]) +
        "\n" +
    """
        BUILD_DIR="$$ABS_RULEDIR/build"
        rm -rf "$$BUILD_DIR"
        mkdir -p "$$BUILD_DIR"

        VARIANT=release

        FFMPEG_VERSION="7.1.1"

        if [ "$(TARGET_CPU)" == "ios_arm64" ]; then
            BUILD_ARCH="arm64"
        elif [ "$(TARGET_CPU)" == "ios_sim_arm64" ]; then
            BUILD_ARCH="sim_arm64"
            VARIANT="debug"
        else
            echo "Unsupported architecture $(TARGET_CPU)"
        fi

        "$$SOURCE_PATH/build-ffmpeg-bazel.sh" "$$VARIANT" "$$BUILD_ARCH" "$$BUILD_DIR" "$$SOURCE_PATH" "$$FFMPEG_VERSION"
    """ + "\n" + "\n".join([
        "cp \"$$BUILD_DIR/FFmpeg-iOS/include/{header_path}\" \"$(location Public/third_party/ffmpeg/{header_path})\"".format(header_path = header_path) for header_path in ffmpeg_header_paths
    ]) + "\n" + "\n".join([
        "cp \"$$BUILD_DIR/FFmpeg-iOS/include/{header_path}\" \"$(location Public/{header_path})\"".format(header_path = header_path) for header_path in ffmpeg_header_paths
    ]) + "\n" + "\n".join([
        "cp \"$$BUILD_DIR/FFmpeg-iOS/lib/{lib}\" \"$(location {lib})\"".format(lib = lib) for lib in ffmpeg_libs
    ]),
    outs = [
        "Public/third_party/ffmpeg/{}".format(header_path) for header_path in ffmpeg_header_paths
    ] + [
        "Public/{}".format(header_path) for header_path in ffmpeg_header_paths
    ] + ffmpeg_libs,
    visibility = [
        "//visibility:public",
    ],
)

cc_library(
    name = "ffmpeg_lib",
    srcs = ffmpeg_libs,
    visibility = [
        "//visibility:public",
    ]
)

objc_library(
    name = "ffmpeg",
    module_name = "ffmpeg",
    enable_modules = True,
    hdrs = ["Public/third_party/ffmpeg/" + x for x in ffmpeg_header_paths] + ["Public/" + x for x in ffmpeg_header_paths],
    includes = [
        "Public",
    ],
    sdk_dylibs = [
        "libbz2",
        "libiconv",
        "z",
    ],
    deps = [
        ":ffmpeg_lib",
        "//third-party/libvpx:vpx",
        "//third-party/opus:opus",
        "//third-party/dav1d:dav1d",
    ],
    visibility = [
        "//visibility:public",
    ]
)
