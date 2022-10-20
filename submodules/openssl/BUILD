openssl_headers = [
    "aes.h",
    "asn1.h",
    "asn1_mac.h",
    "asn1err.h",
    "asn1t.h",
    "async.h",
    "asyncerr.h",
    "bio.h",
    "bioerr.h",
    "blowfish.h",
    "bn.h",
    "bnerr.h",
    "buffer.h",
    "buffererr.h",
    "camellia.h",
    "cast.h",
    "cmac.h",
    "cms.h",
    "cmserr.h",
    "comp.h",
    "comperr.h",
    "conf.h",
    "conf_api.h",
    "conferr.h",
    "crypto.h",
    "cryptoerr.h",
    "ct.h",
    "cterr.h",
    "des.h",
    "dh.h",
    "dherr.h",
    "dsa.h",
    "dsaerr.h",
    "dtls1.h",
    "e_os2.h",
    "ebcdic.h",
    "ec.h",
    "ecdh.h",
    "ecdsa.h",
    "ecerr.h",
    "engine.h",
    "engineerr.h",
    "err.h",
    "evp.h",
    "evperr.h",
    "hmac.h",
    "idea.h",
    "kdf.h",
    "kdferr.h",
    "lhash.h",
    "md2.h",
    "md4.h",
    "md5.h",
    "mdc2.h",
    "modes.h",
    "obj_mac.h",
    "objects.h",
    "objectserr.h",
    "ocsp.h",
    "ocsperr.h",
    "opensslconf.h",
    "opensslv.h",
    "ossl_typ.h",
    "pem.h",
    "pem2.h",
    "pemerr.h",
    "pkcs12.h",
    "pkcs12err.h",
    "pkcs7.h",
    "pkcs7err.h",
    "rand.h",
    "rand_drbg.h",
    "randerr.h",
    "rc2.h",
    "rc4.h",
    "rc5.h",
    "ripemd.h",
    "rsa.h",
    "rsaerr.h",
    "safestack.h",
    "seed.h",
    "sha.h",
    "srp.h",
    "srtp.h",
    "ssl.h",
    "ssl2.h",
    "ssl3.h",
    "sslerr.h",
    "stack.h",
    "store.h",
    "storeerr.h",
    "symhacks.h",
    "tls1.h",
    "ts.h",
    "tserr.h",
    "txt_db.h",
    "ui.h",
    "uierr.h",
    "whrlpool.h",
    "x509.h",
    "x509_vfy.h",
    "x509err.h",
    "x509v3.h",
    "x509v3err.h",
]

openssl_libs = [
    "libcrypto.a",
    "libssl.a",
]

genrule(
    name = "openssl_build",
    srcs = [
        "build-openssl-bazel.sh",
        "openssl-1.1.1d.tar.gz",
        "patch-conf.patch",
        "patch-include.patch",
    ],
    cmd_bash =
        """

        if [ "$(TARGET_CPU)" == "ios_armv7" ]; then
            BUILD_ARCH="armv7"
        elif [ "$(TARGET_CPU)" == "ios_arm64" ]; then
            BUILD_ARCH="arm64"
        elif [ "$(TARGET_CPU)" == "ios_x86_64" ]; then
            BUILD_ARCH="x86_64"
        else
            echo "Unsupported architecture $(TARGET_CPU)"
        fi
        BUILD_DIR="$(RULEDIR)/$$BUILD_ARCH"
        rm -rf "$$BUILD_DIR"
        mkdir -p "$$BUILD_DIR"
        """ + "\n" +
        "mkdir -p $$BUILD_DIR" + "\n" +
        "cp $(SRCS) $$BUILD_DIR/" + "\n" +
        "sh $$BUILD_DIR/build-openssl-bazel.sh $$BUILD_DIR $$BUILD_DIR $$BUILD_ARCH" + "\n" +
        "\n".join([
            "cp \"$$BUILD_DIR/build/$$BUILD_ARCH/include/openssl/{}\" \"$(location :{})\"\n".format(x, x) for x in openssl_headers
        ]) +
        "\n".join([
            "cp \"$$BUILD_DIR/build/$$BUILD_ARCH/lib/{}\" \"$(location :{})\"\n".format(x, x) for x in openssl_libs
        ]),
    outs = openssl_headers + openssl_libs,
    visibility = [
        "//visibility:public",
    ]
)

genrule(
    name = "openssl_include",
    srcs = [":" + x for x in openssl_headers],
    outs = ["Public/openssl/" + x for x in openssl_headers],
    cmd_bash = " && ".join(["cp $(location :{}) $(location Public/openssl/{})".format(x, x) for x in openssl_headers]),
    visibility = [
        "//visibility:public",
    ],
)

cc_library(
    name = "openssl_lib",
    srcs = [":" + x for x in openssl_libs],
)

objc_library(
    name = "openssl",
    module_name = "openssl",
    enable_modules = True,
    hdrs = ["Public/openssl/" + x for x in openssl_headers],
    includes = [
        "Public",
    ],
    deps = [
        ":openssl_lib",
    ],
    visibility = [
        "//visibility:public",
    ]
)
