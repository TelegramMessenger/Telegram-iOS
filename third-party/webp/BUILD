
headers = [
    "decode.h",
    "encode.h",
    "types.h",
    #"demux.h",
    #"mux_types.h",
]

libs = [
    "webp",
]

genrule(
    name = "webp_build",
    srcs = [
        "build-webp-bazel.sh",
        "libwebp-1.1.0.tar.gz",
    ],
    cmd_bash = 
    """
    set -ex

    if [ "$(TARGET_CPU)" == "ios_armv7" ]; then
        BUILD_ARCH="armv7"
    elif [ "$(TARGET_CPU)" == "ios_arm64" ]; then
        BUILD_ARCH="arm64"
    elif [ "$(TARGET_CPU)" == "ios_sim_arm64" ]; then
        BUILD_ARCH="sim_arm64"
    elif [ "$(TARGET_CPU)" == "ios_x86_64" ]; then
        BUILD_ARCH="x86_64"
    else
        echo "Unsupported architecture $(TARGET_CPU)"
    fi

    BUILD_DIR="$(RULEDIR)/build_$${BUILD_ARCH}"
    rm -rf "$$BUILD_DIR"
    mkdir -p "$$BUILD_DIR"

    cp $(location :build-webp-bazel.sh) "$$BUILD_DIR/"
    cp $(location :libwebp-1.1.0.tar.gz) "$$BUILD_DIR/"

    mkdir -p "$$BUILD_DIR/Public/webp"

    sh $$BUILD_DIR/build-webp-bazel.sh $$BUILD_ARCH "$$BUILD_DIR" libwebp-1.1.0.tar.gz
    """ +
    "\n".join([
        "cp -f \"$$BUILD_DIR/src/libwebp-1.1.0/build-output/include/webp/{}\" \"$(location Public/webp/{})\"".format(header, header) for header in headers
    ]) +
    "\n" +
    "\n".join([
        "cp -f \"$$BUILD_DIR/src/libwebp-1.1.0/build-output/lib/lib{}.a\" \"$(location Public/webp/lib/lib{}.a)\"".format(lib, lib) for lib in libs
    ]),
    outs = ["Public/webp/" + x for x in headers] +
    ["Public/webp/lib/lib{}.a".format(x) for x in libs],
    visibility = [
        "//visibility:public",
    ]
)

cc_library(
    name = "webp_lib",
    srcs = [":Public/webp/lib/lib" + x + ".a" for x in libs],
)

objc_library(
    name = "webp",
    module_name = "webp",
    enable_modules = True,
    hdrs = [":Public/webp/" + x for x in headers],
    includes = [
        "Public",
        "Public/webp",
    ],
    deps = [
        ":webp_lib",
    ],
    visibility = [
        "//visibility:public",
    ],
)
