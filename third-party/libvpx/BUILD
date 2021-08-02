
headers = [
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

libs = [
    "VPX",
]

filegroup(
    name = "libvpx_sources",
    srcs = glob([
        "libvpx/**/*"
    ]),
)


genrule(
    name = "libvpx_build",
    srcs = [
        "build-libvpx-bazel.sh",
        "0001-Support-arm64-simulator.patch",
        ":libvpx_sources",
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

    cp $(location :build-libvpx-bazel.sh) "$$BUILD_DIR/"
    cp $(location :0001-Support-arm64-simulator.patch) "$$BUILD_DIR/"

    SOURCE_PATH="third-party/libvpx/libvpx"

    cp -R "$$SOURCE_PATH" "$$BUILD_DIR/"

    pushd "$$BUILD_DIR/libvpx"
    patch -p1 < ../0001-Support-arm64-simulator.patch
    popd

    mkdir -p "$$BUILD_DIR/Public/libvpx"

    PATH="$$PATH:$$ABS_YASM_DIR" sh $$BUILD_DIR/build-libvpx-bazel.sh $$BUILD_ARCH "$$BUILD_DIR/libvpx" "$$BUILD_DIR"
    """ +
    "\n".join([
        "cp -f \"$$BUILD_DIR/VPX.framework/Headers/vpx/{}\" \"$(location Public/vpx/{})\"".format(header, header) for header in headers
    ]) +
    "\n" +
    "\n".join([
        "cp -f \"$$BUILD_DIR/VPX.framework/{}\" \"$(location Public/vpx/lib{}.a)\"".format(lib, lib) for lib in libs
    ]) +
    "\n" + "cp -f \"$$BUILD_DIR/VPX.framework/Headers/vpx/$$PLATFORM_HEADER_DIR/vpx_config.h\" \"$(location Public/vpx/vpx_config.h)\"",
    outs = ["Public/vpx/" + x for x in headers] +
    ["Public/vpx/vpx_config.h"] +
    ["Public/vpx/lib{}.a".format(x) for x in libs],
    tools = [
        "//third-party/yasm:yasm.tar",
    ],
    visibility = [
        "//visibility:public",
    ]
)

cc_library(
    name = "libvpx_lib",
    srcs = [":Public/vpx/lib" + x + ".a" for x in libs],
)

objc_library(
    name = "vpx",
    module_name = "vpx",
    enable_modules = True,
    hdrs = [":Public/vpx/" + x for x in headers],
    includes = [
        "Public",
    ],
    deps = [
        ":libvpx_lib",
    ],
    visibility = [
        "//visibility:public",
    ],
)
