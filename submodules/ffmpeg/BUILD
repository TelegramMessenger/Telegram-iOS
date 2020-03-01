ffmpeg_header_paths = [
    "libavutil/hwcontext.h",
    "libavutil/time.h",
    "libavutil/hwcontext_cuda.h",
    "libavutil/intfloat.h",
    "libavutil/error.h",
    "libavutil/fifo.h",
    "libavutil/blowfish.h",
    "libavutil/hwcontext_mediacodec.h",
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
    "libavutil/avconfig.h",
    "libavutil/lfg.h",
    "libavutil/avutil.h",
    "libavutil/xtea.h",
    "libavutil/crc.h",
    "libavutil/hwcontext_vdpau.h",
    "libavutil/frame.h",
    "libavutil/file.h",
    "libavutil/md5.h",
    "libavutil/cast5.h",
    "libavutil/hwcontext_vaapi.h",
    "libavutil/spherical.h",
    "libavutil/ffversion.h",
    "libavutil/audio_fifo.h",
    "libavutil/tree.h",
    "libavutil/threadmessage.h",
    "libavutil/attributes.h",
    "libavutil/adler32.h",
    "libavutil/hwcontext_d3d11va.h",
    "libavutil/timecode.h",
    "libavutil/sha512.h",
    "libavutil/hwcontext_dxva2.h",
    "libavutil/display.h",
    "libavutil/buffer.h",
    "libavutil/camellia.h",
    "libavutil/pixelutils.h",
    "libavutil/hwcontext_drm.h",
    "libavutil/common.h",
    "libavutil/hmac.h",
    "libavutil/eval.h",
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
    "libavutil/mem.h",
    "libavutil/parseutils.h",
    "libavutil/ripemd.h",
    "libavutil/bprint.h",
    "libavutil/hwcontext_qsv.h",
    "libavutil/pixfmt.h",
    "libavutil/aes_ctr.h",
    "libavutil/timestamp.h",
    "libavutil/downmix_info.h",
    "libavutil/avassert.h",
    "libavutil/hash.h",
    "libavutil/mathematics.h",
    "libavutil/intreadwrite.h",
    "libavutil/avstring.h",
    "libavformat/version.h",
    "libavformat/avio.h",
    "libavformat/avformat.h",
    "libavcodec/adts_parser.h",
    "libavcodec/avcodec.h",
    "libavcodec/version.h",
    "libavcodec/vdpau.h",
    "libavcodec/qsv.h",
    "libavcodec/vaapi.h",
    "libavcodec/videotoolbox.h",
    "libavcodec/xvmc.h",
    "libavcodec/mediacodec.h",
    "libavcodec/d3d11va.h",
    "libavcodec/avfft.h",
    "libavcodec/jni.h",
    "libavcodec/dirac.h",
    "libavcodec/avdct.h",
    "libavcodec/ac3_parser.h",
    "libavcodec/vorbis_parser.h",
    "libavcodec/dxva2.h",
    "libavcodec/dv_profile.h",
    "libswresample/version.h",
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

genrule(
    name = "libffmpeg_build",
    srcs = [
        ":FFMpegSources",
    ],
    cmd_bash =
    """
        SOURCE_PATH="submodules/ffmpeg/Sources/FFMpeg"

        BUILD_DIR="$(RULEDIR)/build"
        rm -rf "$$BUILD_DIR"
        mkdir -p "$$BUILD_DIR"
        YASM_DIR="$$BUILD_DIR/yasm"
        rm -rf "$$YASM_DIR"
        mkdir -p "$$YASM_DIR"
        tar -xf "$(location //third-party/yasm:yasm.tar)" -C "$$YASM_DIR"

        if [ "$(TARGET_CPU)" == "ios_armv7" ]; then
            BUILD_ARCH="armv7"
        elif [ "$(TARGET_CPU)" == "ios_arm64" ]; then
            BUILD_ARCH="arm64"
        elif [ "$(TARGET_CPU)" == "ios_x86_64" ]; then
            BUILD_ARCH="x86_64"
        else
            echo "Unsupported architecture $(TARGET_CPU)"
        fi

        PATH="$$PATH:$$YASM_DIR" "$$SOURCE_PATH/build-ffmpeg-bazel.sh" release "$$BUILD_ARCH" "$$BUILD_DIR" "$$SOURCE_PATH"
    """ + "\n" + "\n".join([
        "cp \"$$BUILD_DIR/FFmpeg-iOS/include/{header_path}\" \"$(location Public/ffmpeg/{header_path})\"".format(header_path = header_path) for header_path in ffmpeg_header_paths
    ]) + "\n" + "\n".join([
        "cp \"$$BUILD_DIR/FFmpeg-iOS/lib/{lib}\" \"$(location {lib})\"".format(lib = lib) for lib in ffmpeg_libs
    ]),
    outs = [
        "Public/ffmpeg/{}".format(header_path) for header_path in ffmpeg_header_paths
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
)

objc_library(
    name = "ffmpeg",
    module_name = "ffmpeg",
    enable_modules = True,
    hdrs = ["Public/ffmpeg/" + x for x in ffmpeg_header_paths],
    includes = [
        "Public/ffmpeg",
    ],
    sdk_dylibs = [
        "libbz2",
        "libiconv",
        "z",
    ],
    deps = [
        ":ffmpeg_lib",
        "//submodules/Opus:opus",
    ],
    visibility = [
        "//visibility:public",
    ]
)
