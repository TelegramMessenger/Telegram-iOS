
headers = [
    "x264.h",
    "x264_config.h",
]

libs = [
    "x264",
]

filegroup(
    name = "libx264_sources",
    srcs = glob([
        "x264/**/*"
    ], exclude = [
        "x264/.git/**/*"
    ]),
)


genrule(
    name = "lib264_build",
    srcs = [
        "build-libx264-bazel.sh",
        ":libx264_sources",
    ],
    cmd_bash = 
    """
    set -ex

    if [ "$(TARGET_CPU)" == "ios_armv7" ]; then
        BUILD_ARCH="armv7"
        PLATFORM_HEADER_DIR="armv7-darwin-gcc"
    elif [ "$(TARGET_CPU)" == "ios_arm64" ]; then
        BUILD_ARCH="arm64"
        PLATFORM_HEADER_DIR="arm64-darwin-gcc"
    elif [ "$(TARGET_CPU)" == "ios_sim_arm64" ]; then
        BUILD_ARCH="sim_arm64"
        PLATFORM_HEADER_DIR="arm64-iphonesimulator-gcc"
    elif [ "$(TARGET_CPU)" == "ios_x86_64" ]; then
        BUILD_ARCH="x86_64"
        PLATFORM_HEADER_DIR="x86_64-iphonesimulator-gcc"
    else
        echo "Unsupported architecture $(TARGET_CPU)"
    fi

    BUILD_DIR="$(RULEDIR)/build_$${BUILD_ARCH}"
    rm -rf "$$BUILD_DIR"
    mkdir -p "$$BUILD_DIR"

    YASM_DIR="$$BUILD_DIR/yasm"
    rm -rf "$$YASM_DIR"
    mkdir -p "$$YASM_DIR"
    tar -xf "$(location //third-party/yasm:yasm.tar)" -C "$$YASM_DIR"
    ABS_YASM_DIR="$$(pwd)/$$(dirname $$YASM_DIR)/$$(basename $$YASM_DIR)"

    cp $(location :build-libx264-bazel.sh) "$$BUILD_DIR/"

    SOURCE_PATH="third-party/libx264/x264"

    cp -R "$$SOURCE_PATH" "$$BUILD_DIR/"

    mkdir -p "$$BUILD_DIR/Public/libx264"

    PATH="$$PATH:$$ABS_YASM_DIR" sh $$BUILD_DIR/build-libx264-bazel.sh $$BUILD_ARCH "$$BUILD_DIR/x264" "$$BUILD_DIR"
    """ +
    "\n".join([
        "cp -f \"$$BUILD_DIR/scratch/thin/include/{}\" \"$(location Public/libx264/{})\"".format(header, header) for header in headers
    ]) +
    "\n" +
    "\n".join([
        "cp -f \"$$BUILD_DIR/scratch/thin/lib/lib{}.a\" \"$(location Public/libx264/lib{}.a)\"".format(lib, lib) for lib in libs
    ]) +
    "\n",
    outs = ["Public/libx264/" + x for x in headers] +
    ["Public/libx264/lib{}.a".format(x) for x in libs],
    tools = [
        "//third-party/yasm:yasm.tar",
    ],
    visibility = [
        "//visibility:public",
    ]
)

cc_library(
    name = "libx264_lib",
    srcs = [":Public/libx264/lib" + x + ".a" for x in libs],
)

cc_library(
    name = "libx264",
    srcs = [
"x264/common/osdep.c",
"x264/common/base.c",
"x264/common/cpu.c",
"x264/common/tables.c",
"x264/encoder/api.c",
"x264/common/mc.c",
"x264/common/predict.c",
"x264/common/pixel.c",
"x264/common/macroblock.c",
"x264/common/frame.c",
"x264/common/dct.c",
"x264/common/cabac.c",
"x264/common/common.c",
"x264/common/rectangle.c",
"x264/common/set.c",
"x264/common/quant.c",
"x264/common/deblock.c",
"x264/common/vlc.c",
"x264/common/mvpred.c",
"x264/common/bitstream.c",
"x264/encoder/analyse.c",
"x264/encoder/me.c",
"x264/encoder/ratecontrol.c",
"x264/encoder/set.c",
"x264/encoder/macroblock.c",
"x264/encoder/cabac.c",
"x264/encoder/cavlc.c",
"x264/encoder/encoder.c",
"x264/encoder/lookahead.c",
"x264/common/threadpool.c",

"x264/encoder/analyse.h",
"x264/encoder/macroblock.h",
"x264/encoder/me.h",
"x264/encoder/ratecontrol.h",
"x264/encoder/set.h",
"x264/common/base.h",
"x264/common/osdep.h",
"x264/common/cpu.h",
"x264/common/tables.h",
"x264/common/common.h",
"x264/common/cabac.h",
"x264/common/bitstream.h",
"x264/common/set.h",
"x264/common/predict.h",
"x264/common/pixel.h",
"x264/common/mc.h",
"x264/common/frame.h",
"x264/common/dct.h",
"x264/common/quant.h",
"x264/common/threadpool.h",
"x264/common/macroblock.h",
"x264/common/rectangle.h",
"Public/libx264/x264_config.h",
"config/config.h",
"x264/x264.h",

"x264/common/aarch64/asm-offsets.h",
"x264/common/aarch64/bitstream.h",
"x264/common/aarch64/deblock.h",
"x264/common/aarch64/dct.h",
"x264/common/aarch64/mc.h",
"x264/common/aarch64/predict.h",
"x264/common/aarch64/quant.h",
"x264/common/aarch64/pixel.h",

"x264/common/aarch64/cabac-a.S",
"x264/common/aarch64/dct-a.S",
"x264/common/aarch64/deblock-a.S",
"x264/common/aarch64/mc-a.S",
"x264/common/aarch64/pixel-a.S",
"x264/common/aarch64/predict-a.S",
"x264/common/aarch64/quant-a.S",
"x264/common/aarch64/bitstream-a.S",

"x264/common/aarch64/asm-offsets.c",
"x264/common/aarch64/mc-c.c",
"x264/common/aarch64/predict-c.c",
    ],
    hdrs = [
"x264/encoder/rdo.c",
"x264/encoder/cavlc.c",
"x264/encoder/cabac.c",
"x264/encoder/slicetype.c",
"x264/common/aarch64/asm.S",
    ],
    includes = [
        "Public",
    ],
    copts = [
        "-Ithird-party/libx264/x264",
        "-Ithird-party/libx264/config",
        "-Ithird-party/libx264/Public/libx264",
        "-DBIT_DEPTH=8",
        "-DHIGH_BIT_DEPTH=0",
        "-DPREFIX",
        "-Dprivate_prefix=x264_8",
    ],
    visibility = [
        "//visibility:public",
    ],
)

objc_library(
    name = "libx264_old",
    module_name = "libx264_old",
    enable_modules = True,
    hdrs = [":Public/libx264/" + x for x in headers],
    includes = [
        "Public",
    ],
    deps = [
        ":libx264_lib",
        ":libx264_from_source",
    ],
    visibility = [
        "//visibility:public",
    ],
)
