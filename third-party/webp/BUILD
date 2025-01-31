
headers = [
    "decode.h",
    "encode.h",
    "types.h",
]

libs = [
    "webp",
    "sharpyuv",
]

# libwebp at c1ffd9ac7593894c40a1de99d03f0b7af8af2577
filegroup(
    name = "libwebp_sources",
    srcs = glob([
        "libwebp/**/*"
    ]),
)

genrule(
    name = "webp_build",
    srcs = [
        "build-webp-bazel.sh",
        ":libwebp_sources",
        "@cmake_tar_gz//file",
    ],
    cmd_bash = 
    """
    set -ex

    if [ "$(TARGET_CPU)" == "ios_arm64" ]; then
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

    CMAKE_DIR="$$(pwd)/$$BUILD_DIR/cmake"
    rm -rf "$$CMAKE_DIR"
    mkdir -p "$$CMAKE_DIR"
    tar -xzf "$(location @cmake_tar_gz//file)" -C "$$CMAKE_DIR"

    cp $(location :build-webp-bazel.sh) "$$BUILD_DIR/"

    SOURCE_PATH="third-party/webp/libwebp"

    cp -R "$$SOURCE_PATH" "$$BUILD_DIR/"

    mkdir -p "$$BUILD_DIR/Public/libwebp"

    PATH="$$PATH:$$CMAKE_DIR/cmake-3.23.1-macos-universal/CMake.app/Contents/bin" sh $$BUILD_DIR/build-webp-bazel.sh $$BUILD_ARCH "$$BUILD_DIR/libwebp" "$$BUILD_DIR" >/dev/null 2>&1
    """ +
    "\n".join([
        "cp -f \"$$BUILD_DIR/libwebp/src/webp/{}\" \"$(location Public/webp/{})\"".format(header, header) for header in headers
    ]) +
    "\n" +
    "\n".join([
        "cp -f \"$$BUILD_DIR/build/lib{}.a\" \"$(location Public/webp/lib/lib{}.a)\"".format(lib, lib) for lib in libs
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
