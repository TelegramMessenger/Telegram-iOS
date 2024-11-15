
generated_headers = [
    "vcs_version.h",
]

headers = [
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

libs = [
    "dav1d",
]

filegroup(
    name = "dav1d_sources",
    srcs = glob([
        "dav1d/**/*"
    ]),
)

genrule(
    name = "dav1d_build",
    srcs = [
        "build-dav1d-bazel.sh",
        "arm64-iPhoneSimulator.meson",
        ":dav1d_sources",
        "@meson_tar_gz//file",
        "@ninja-mac_zip//file",
    ],
    cmd_bash = 
    """
    set -ex

    if [ "$(TARGET_CPU)" == "ios_arm64" ]; then
        BUILD_ARCH="arm64"
    elif [ "$(TARGET_CPU)" == "ios_sim_arm64" ]; then
        BUILD_ARCH="sim_arm64"
    else
        echo "Unsupported architecture $(TARGET_CPU)"
    fi

    BUILD_DIR="$(RULEDIR)/build_$${BUILD_ARCH}"
    rm -rf "$$BUILD_DIR"
    mkdir -p "$$BUILD_DIR"

    MESON_DIR="$$(pwd)/$$BUILD_DIR/meson"
    rm -rf "$$MESON_DIR"
    mkdir -p "$$MESON_DIR"
    tar -xzf "$(location @meson_tar_gz//file)" -C "$$MESON_DIR"

    NINJA_DIR="$$(pwd)/$$BUILD_DIR/ninja"
    rm -rf "$$NINJA_DIR"
    mkdir -p "$$NINJA_DIR"
    unzip "$(location @ninja-mac_zip//file)" -d "$$NINJA_DIR"

    cp $(location :build-dav1d-bazel.sh) "$$BUILD_DIR/"
    cp $(location :arm64-iPhoneSimulator.meson) "$$BUILD_DIR/"

    SOURCE_PATH="third-party/dav1d/dav1d"

    cp -R "$$SOURCE_PATH" "$$BUILD_DIR/"

    mkdir -p "$$BUILD_DIR/Public/dav1d"
    mkdir -p "$$BUILD_DIR/Public/compat"
    mkdir -p "$$BUILD_DIR/Public/common"

    PATH="$$PATH:$$MESON_DIR/meson-1.6.0:$$NINJA_DIR" sh $$BUILD_DIR/build-dav1d-bazel.sh $$BUILD_ARCH "$$BUILD_DIR"
    """ +
    "\n".join([
        "cp -f \"$$BUILD_DIR/dav1d/build/include/{}\" \"$(location Public/{})\"".format(header, header) for header in generated_headers
    ]) +
    "\n" +
    "\n".join([
        "cp -f \"$$BUILD_DIR/dav1d/include/{}\" \"$(location Public/{})\"".format(header, header) for header in headers
    ]) +
    "\n" +
    "\n".join([
        "cp -f \"$$BUILD_DIR/dav1d/build/src/lib{}.a\" \"$(location Public/dav1d/lib/lib{}.a)\"".format(lib, lib) for lib in libs
    ]),
    outs = ["Public/" + x for x in generated_headers] +
    ["Public/" + x for x in headers] +
    ["Public/dav1d/lib/lib{}.a".format(x) for x in libs],
    visibility = [
        "//visibility:public",
    ]
)

cc_library(
    name = "dav1d_lib",
    srcs = [":Public/dav1d/lib/lib" + x + ".a" for x in libs]
)

objc_library(
    name = "dav1d",
    module_name = "dav1d",
    enable_modules = True,
    hdrs = [":Public/" + x for x in generated_headers],
    includes = [
        "Public",
    ],
    deps = [
        ":dav1d_lib",
    ],
    visibility = [
        "//visibility:public",
    ],
)

