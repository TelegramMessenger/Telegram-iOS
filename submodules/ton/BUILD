ton_headers = [
    "auto/tl/tonlib_api.h",
    "tl/TlObject.h",
    "tonlib/tonlib_client_json.h",
    "tonlib/tonlibjson_export.h",
    "tonlib/Client.h",
    "td/utils/Slice-decl.h",
    "td/utils/config.h",
    "td/utils/SharedSlice.h",
    "td/utils/Slice.h",
    "td/utils/int_types.h",
    "td/utils/common.h",
    "td/utils/check.h",
    "td/utils/unique_ptr.h",
    "td/utils/port/platform.h",
]

ton_lib_names = [
    "adnllite",
    "crc32c",
    "keys",
    "lite-client-common",
    "smc-envelope",
    "tdactor",
    "tddb",
    "tdnet",
    "tdutils",
    "tl-lite-utils",
    "tl-utils",
    "tl_api",
    "tl_lite_api",
    "tl_tonlib_api",
    "ton_block",
    "ton_crypto",
    "tonlib",
]

genrule(
    name = "ton_build",
    srcs = [
        "build-ton-bazel.sh",
        "iOS-bazel.cmake",
        "tonlib-src.tar.gz",
        "//submodules/openssl:openssl_include",
        "//submodules/openssl:libcrypto.a",
    ],
    cmd_bash = 
    """
    set -ex

    if [ "$(TARGET_CPU)" == "ios_armv7" ]; then
        BUILD_ARCH="armv7"
    elif [ "$(TARGET_CPU)" == "ios_arm64" ]; then
        BUILD_ARCH="arm64"
    elif [ "$(TARGET_CPU)" == "ios_x86_64" ]; then
        BUILD_ARCH="x86_64"
    else
        echo "Unsupported architecture $(TARGET_CPU)"
    fi

    cp $(location :build-ton-bazel.sh) "$(RULEDIR)/"
    cp $(location :iOS-bazel.cmake) "$(RULEDIR)/"
    tar -xzf $(location tonlib-src.tar.gz) -C "$(RULEDIR)/"

    mkdir -p "$(RULEDIR)/openssl_headers/include/openssl"
    mkdir -p "$(RULEDIR)/openssl_headers/lib"
    cp -f "$(location //submodules/openssl:libcrypto.a)" "$(RULEDIR)/openssl_headers/lib/"
    for f in $(locations //submodules/openssl:openssl_include); do
        cp -f "$$f" "$(RULEDIR)/openssl_headers/include/openssl/"
    done
    mkdir -p "$(RULEDIR)/Public/ton"

    sh $(RULEDIR)/build-ton-bazel.sh "$(RULEDIR)" "$(RULEDIR)" "$(RULEDIR)/openssl_headers" $$BUILD_ARCH
    """ +
    "\n".join([
        "cp -f \"$(RULEDIR)/build/out/include/{}\" \"$(location Public/ton/include/{})\"".format(header, header) for header in ton_headers
    ]) +
    "\n" +
    "\n".join([
        "cp -f \"$(RULEDIR)/build/out/lib/lib{}.a\" \"$(location Public/ton/lib/lib{}.a)\"".format(lib, lib) for lib in ton_lib_names
    ]),
    outs = ["Public/ton/include/" + x for x in ton_headers] +
    ["Public/ton/lib/lib{}.a".format(x) for x in ton_lib_names],
    visibility = [
        "//visibility:public",
    ]
)

cc_library(
    name = "ton_lib",
    srcs = [":Public/ton/lib/lib" + x + ".a" for x in ton_lib_names],
)

objc_library(
    name = "ton",
    module_name = "ton",
    enable_modules = True,
    hdrs = [":Public/ton/include/" + x for x in ton_headers],
    includes = [
        "Public/ton/include",
    ],
    deps = [
        ":ton_lib",
    ],
    visibility = [
        "//visibility:public",
    ],
)
