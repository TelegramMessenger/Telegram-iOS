
headers = [
    "turbojpeg.h",
    "jpeglib.h",
    "jmorecfg.h",
]

libs = [
    "jpeg",
    "turbojpeg"
]

filegroup(
    name = "mozjpeg_sources",
    srcs = glob([
        "mozjpeg/**/*"
    ]),
)

genrule(
    name = "mozjpeg_build",
    srcs = [
        "build-mozjpeg-bazel.sh",
        ":mozjpeg_sources",
        "@cmake_tar_gz//file",
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

    CMAKE_DIR="$$(pwd)/$$BUILD_DIR/cmake"
    rm -rf "$$CMAKE_DIR"
    mkdir -p "$$CMAKE_DIR"
    tar -xzf "$(location @cmake_tar_gz//file)" -C "$$CMAKE_DIR"

    cp $(location :build-mozjpeg-bazel.sh) "$$BUILD_DIR/"

    SOURCE_PATH="third-party/mozjpeg/mozjpeg"

    cp -R "$$SOURCE_PATH" "$$BUILD_DIR/"

    mkdir -p "$$BUILD_DIR/Public/mozjpeg"

    PATH="$$PATH:$$CMAKE_DIR/cmake-3.23.1-macos-universal/CMake.app/Contents/bin" sh $$BUILD_DIR/build-mozjpeg-bazel.sh $$BUILD_ARCH "$$BUILD_DIR/mozjpeg" "$$BUILD_DIR"
    """ +
    "\n".join([
        "cp -f \"$$BUILD_DIR/mozjpeg/{}\" \"$(location Public/mozjpeg/{})\"".format(header, header) for header in headers
    ]) +
    "\n" +
    "\n".join([
        "cp -f \"$$BUILD_DIR/build/lib{}.a\" \"$(location Public/mozjpeg/lib/lib{}.a)\"".format(lib, lib) for lib in libs
    ]) +
    "\n" + "cp -f \"$$BUILD_DIR/build/jconfig.h\" \"$(location Public/mozjpeg/jconfig.h)\"",
    outs = ["Public/mozjpeg/" + x for x in headers] +
    ["Public/mozjpeg/jconfig.h"] +
    ["Public/mozjpeg/lib/lib{}.a".format(x) for x in libs],
    visibility = [
        "//visibility:public",
    ]
)

cc_library(
    name = "mozjpeg_lib",
    srcs = [":Public/mozjpeg/lib/lib" + x + ".a" for x in libs],
)

objc_library(
    name = "mozjpeg",
    module_name = "mozjpeg",
    enable_modules = True,
    hdrs = [":Public/mozjpeg/" + x for x in headers] + [":Public/mozjpeg/jconfig.h"],
    includes = [
        "Public",
        "Public/mozjpeg",
    ],
    deps = [
        ":mozjpeg_lib",
    ],
    visibility = [
        "//visibility:public",
    ],
)
