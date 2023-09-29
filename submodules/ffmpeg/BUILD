avcodec_headers = [
    "ac3_parser.h",
    "adts_parser.h",
    "avcodec.h",
    "avdct.h",
    "avfft.h",
    "bsf.h",
    "codec_desc.h",
    "codec_id.h",
    "codec_par.h",
    "codec.h",
    "d3d11va.h",
    "defs.h",
    "dirac.h",
    "dv_profile.h",
    "dxva2.h",
    "jni.h",
    "mediacodec.h",
    "packet.h",
    "qsv.h",
    "vdpau.h",
    "version_major.h",
    "version.h",
    "videotoolbox.h",
    "vorbis_parser.h",
    "xvmc.h",
]

avformat_headers = [
    "avformat.h",
    "avio.h",
    "version_major.h",
    "version.h",
]

avutil_headers = [
    "adler32.h",
    "aes_ctr.h",
    "aes.h",
    "ambient_viewing_environment.h",
    "attributes.h",
    "audio_fifo.h",
    "avassert.h",
    "avconfig.h",
    "avstring.h",
    "avutil.h",
    "base64.h",
    "blowfish.h",
    "bprint.h",
    "bswap.h",
    "buffer.h",
    "camellia.h",
    "cast5.h",
    "channel_layout.h",
    "common.h",
    "cpu.h",
    "crc.h",
    "csp.h",
    "des.h",
    "detection_bbox.h",
    "dict.h",
    "display.h",
    "dovi_meta.h",
    "downmix_info.h",
    "encryption_info.h",
    "error.h",
    "eval.h",
    "ffversion.h",
    "fifo.h",
    "file.h",
    "film_grain_params.h",
    "frame.h",
    "hash.h",
    "hdr_dynamic_metadata.h",
    "hdr_dynamic_vivid_metadata.h",
    "hmac.h",
    "hwcontext_cuda.h",
    "hwcontext_d3d11va.h",
    "hwcontext_drm.h",
    "hwcontext_dxva2.h",
    "hwcontext_mediacodec.h",
    "hwcontext_opencl.h",
    "hwcontext_qsv.h",
    "hwcontext_vaapi.h",
    "hwcontext_vdpau.h",
    "hwcontext_videotoolbox.h",
    "hwcontext_vulkan.h",
    "hwcontext.h",
    "imgutils.h",
    "intfloat.h",
    "intreadwrite.h",
    "lfg.h",
    "log.h",
    "lzo.h",
    "macros.h",
    "mastering_display_metadata.h",
    "mathematics.h",
    "md5.h",
    "mem.h",
    "motion_vector.h",
    "murmur3.h",
    "opt.h",
    "parseutils.h",
    "pixdesc.h",
    "pixelutils.h",
    "pixfmt.h",
    "random_seed.h",
    "rational.h",
    "rc4.h",
    "replaygain.h",
    "ripemd.h",
    "samplefmt.h",
    "sha.h",
    "sha512.h",
    "spherical.h",
    "stereo3d.h",
    "tea.h",
    "threadmessage.h",
    "time.h",
    "timecode.h",
    "timestamp.h",
    "tree.h",
    "twofish.h",
    "tx.h",
    "uuid.h",
    "version.h",
    "video_enc_params.h",
    "xtea.h",
]

swresample_headers = [
    "swresample.h",
    "version_major.h",
    "version.h",
]


ffmpeg_header_paths = [
    "libavcodec/{}".format(x) for x in avcodec_headers
] + [
    "libavformat/{}".format(x) for x in avformat_headers
] + [
    "libavutil/{}".format(x) for x in avutil_headers
] + [
    "libswresample/{}".format(x) for x in swresample_headers
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
    ],
    cmd_bash =
    """
        #set -x

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
        BUILD_DIR="$$ABS_RULEDIR/build"
        rm -rf "$$BUILD_DIR"
        mkdir -p "$$BUILD_DIR"
        YASM_DIR="$$BUILD_DIR/yasm"
        rm -rf "$$YASM_DIR"
        mkdir -p "$$YASM_DIR"
        tar -xf "$(location //third-party/yasm:yasm.tar)" -C "$$YASM_DIR"

        VARIANT=release

        if [ "$(TARGET_CPU)" == "ios_armv7" ]; then
            BUILD_ARCH="armv7"
        elif [ "$(TARGET_CPU)" == "ios_arm64" ]; then
            BUILD_ARCH="arm64"
        elif [ "$(TARGET_CPU)" == "ios_sim_arm64" ]; then
            BUILD_ARCH="sim_arm64"
            VARIANT="debug"
        elif [ "$(TARGET_CPU)" == "ios_x86_64" ]; then
            BUILD_ARCH="x86_64"
        else
            echo "Unsupported architecture $(TARGET_CPU)"
        fi

        PATH="$$PATH:$$YASM_DIR" "$$SOURCE_PATH/build-ffmpeg-bazel.sh" "$$VARIANT" "$$BUILD_ARCH" "$$BUILD_DIR" "$$SOURCE_PATH"
    """ + "\n" + "\n".join([
        "cp \"$$BUILD_DIR/FFmpeg-iOS/include/{header_path}\" \"$(location Public/third_party/ffmpeg/{header_path})\"".format(header_path = header_path) for header_path in ffmpeg_header_paths
    ]) + "\n" + "\n".join([
        "cp \"$$BUILD_DIR/FFmpeg-iOS/lib/{lib}\" \"$(location {lib})\"".format(lib = lib) for lib in ffmpeg_libs
    ]),
    outs = [
        "Public/third_party/ffmpeg/{}".format(header_path) for header_path in ffmpeg_header_paths
    ] + ffmpeg_libs,
    tools = [
        "//third-party/yasm:yasm.tar",
    ],
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
    hdrs = ["Public/third_party/ffmpeg/" + x for x in ffmpeg_header_paths],
    includes = [
        "Public",
        "Public/third_party/ffmpeg",
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
    ],
    visibility = [
        "//visibility:public",
    ]
)
