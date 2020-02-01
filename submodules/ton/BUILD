load(
    "@rules_apple_extras//apple:objc_library.bzl",
    "objc_library",
)

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
    name = "",
)

genrule(
    name = "ton_build",
    srcs = [
        "build-ton.sh",
        "iOS.cmake",
        "tonlib-src.zip",
        "//submodules/openssl:openssl_include",
    ],
    cmd_bash = 
    """
    cp $(location :build-ton.sh) "$(RULEDIR)/"
    cp $(location :iOS.cmake) "$(RULEDIR)/"
    unzip 
    cp $(location :iOS.cmake) "$(RULEDIR)/"
    "tonlib-src.zip",

    mkdir -p "$(RULEDIR)/openssl_headers/openssl"
    for f in $(locations //submodules/openssl:openssl_include); do
        cp -f "$$f" "$(RULEDIR)/openssl_headers/openssl/"
    done
    mkdir -p "$(RULEDIR)/Public/ton"

    sh $(RULEDIR)/build-ton.sh "$(RULEDIR)/Public/ton" $(RULEDIR) "$(RULEDIR)/openssl_headers"
    """,
    outs = ["Public/ton/" + x for x in ton_headers],
    visibility = [
        "//visibility:public",
    ]
)

#ton_header_targets = gen_header_targets(ton_header_paths, "ton_header_", "", "ton_build", "build/out/include")

cc_library(
    name = "ton_lib",
    srcs = [":lib" + x + ".a" for x in ton_lib_names],
)

objc_library(
    name = "ton",
    hdrs = ["Public/ton/" + x for x in ton_headers],
    deps = [
        ":ton_lib",
    ],
    visibility = [
        "//visibility:public",
    ],
)
