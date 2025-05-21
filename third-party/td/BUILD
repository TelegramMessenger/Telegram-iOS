load(
    "//third-party/boringssl:BUILD.generated.bzl",
    "crypto_headers",
)

headers = [
    "td/e2e/e2e_api.h",
    "td/e2e/e2e_errors.h",
]

libs = [
    "tde2e",
    "tdutils",
]

filegroup(
    name = "td_sources",
    srcs = glob([
        "td/**/*"
    ]),
)

genrule(
    name = "td_build",
    srcs = [
        "build-td-bazel.sh",
        ":td_sources",
        "@cmake_tar_gz//file",
        "//third-party/boringssl:crypto",
    ] + [
        "//third-party/boringssl:{}".format(header) for header in crypto_headers
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

    CMAKE_DIR="$$(pwd)/$$BUILD_DIR/cmake"
    rm -rf "$$CMAKE_DIR"
    mkdir -p "$$CMAKE_DIR"
    tar -xzf "$(location @cmake_tar_gz//file)" -C "$$CMAKE_DIR"

    OPENSSL_BASE_DIR="$$(pwd)/$$BUILD_DIR"
    OPENSSL_DIR="$$OPENSSL_BASE_DIR/openssl"
    rm -rf "$$OPENSSL_DIR"
    mkdir -p "$$OPENSSL_DIR"
    mkdir -p "$$OPENSSL_DIR/lib"
    mkdir -p "$$OPENSSL_DIR/src/include/openssl"
    mkdir -p "$$OPENSSL_DIR/src/include/openssl/experimental"
    
    cp -R "$(location //third-party/boringssl:crypto)" "$$OPENSSL_DIR/lib/libcrypto.a"

    # Copy header files
    """ +
    "\n".join([
        "cp -f \"$(location //third-party/boringssl:{})\" \"$$OPENSSL_DIR/{}\"".format(header, header) 
        for header in crypto_headers
    ]) +
    """

    cp $(location :build-td-bazel.sh) "$$BUILD_DIR/"

    SOURCE_PATH="third-party/td/td"

    cp -R "$$SOURCE_PATH" "$$BUILD_DIR/"

    mkdir -p "$$BUILD_DIR/Public/td"

    PATH="$$PATH:$$CMAKE_DIR/cmake-3.23.1-macos-universal/CMake.app/Contents/bin" sh $$BUILD_DIR/build-td-bazel.sh $$BUILD_ARCH "$$BUILD_DIR/td" "$$BUILD_DIR" "$$OPENSSL_DIR"
    """ +
    "\n".join([
        "cp -f \"$$BUILD_DIR/td/tde2e/{}\" \"$(location Public/td/{})\"".format(header, header) for header in headers
    ]) +
    "\n" +
    "\n".join([
        "cp -f \"$$BUILD_DIR/build/tde2e/libtde2e.a\" \"$(location Public/td/lib/libtde2e.a)\"",
        "cp -f \"$$BUILD_DIR/build/tdutils/libtdutils.a\" \"$(location Public/td/lib/libtdutils.a)\"",
    ]),
    outs = [
        "Public/td/" + x for x in headers
    ] +
    [
        "Public/td/lib/lib{}.a".format(x) for x in libs
    ],
    visibility = [
        "//visibility:public",
    ]
)

cc_library(
    name = "td_lib",
    srcs = [":Public/td/lib/lib" + x + ".a" for x in libs],
)

objc_library(
    name = "td",
    module_name = "td",
    enable_modules = True,
    hdrs = [":Public/td/" + x for x in headers],
    includes = [
        "Public/td",
    ],
    deps = [
        ":td_lib",
        "//third-party/boringssl:crypto",
    ],
    visibility = [
        "//visibility:public",
    ],
)

objc_library(
    name = "TdBinding",
    module_name = "TdBinding",
    enable_modules = True,
    srcs = glob([
        "TdBinding/Sources/**/*.m",
        "TdBinding/Sources/**/*.mm",
        "TdBinding/Sources/**/*.h",
    ], allow_empty=True),
    hdrs = glob([
        "TdBinding/Public/**/*.h",
    ]),
    copts = [
        "-Werror",
    ],
    cxxopts = [
        "-Werror",
        "-std=c++17",
    ],
    includes = [
        "TdBinding/Public",
    ],
    deps = [
        ":td",
    ],
    sdk_frameworks = [
    ],
    visibility = [
        "//visibility:public",
    ]
)
