
headers = [
    "opus.h",
    "opus_defines.h",
    "opus_multistream.h",
    "opus_projection.h",
    "opus_types.h",
]

libs = [
    "opus",
]

genrule(
    name = "opus_build",
    srcs = [
        "build-opus-bazel.sh",
        "opus-1.3.1.tar.gz",
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

    cp $(location :build-opus-bazel.sh) "$$BUILD_DIR/"
    cp $(location :opus-1.3.1.tar.gz) "$$BUILD_DIR/"

    mkdir -p "$$BUILD_DIR/Public/opus"

    sh $$BUILD_DIR/build-opus-bazel.sh $$BUILD_ARCH "$$BUILD_DIR" opus-1.3.1.tar.gz
    """ +
    "\n".join([
        "cp -f \"$$BUILD_DIR/built/include/opus/{}\" \"$(location Public/opus/{})\"".format(header, header) for header in headers
    ]) +
    "\n" +
    "\n".join([
        "cp -f \"$$BUILD_DIR/built/lib/lib{}.a\" \"$(location Public/opus/lib/lib{}.a)\"".format(lib, lib) for lib in libs
    ]),
    outs = ["Public/opus/" + x for x in headers] +
    ["Public/opus/lib/lib{}.a".format(x) for x in libs],
    visibility = [
        "//visibility:public",
    ]
)

cc_library(
    name = "opus_lib",
    srcs = [":Public/opus/lib/lib" + x + ".a" for x in libs],
)

objc_library(
    name = "opus",
    module_name = "opus",
    enable_modules = True,
    hdrs = [":Public/opus/" + x for x in headers],
    includes = [
        "Public",
        "Public/opus",
    ],
    deps = [
        ":opus_lib",
    ],
    visibility = [
        "//visibility:public",
    ],
)
