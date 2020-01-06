load(
    "//Config/objc_module_provider.bzl",
    "objc_module",
)

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
]

archs = ["arm64", "armv7", "x86_64"]

rules = [
    genrule(
        name = "openssl_build_" + arch,
        srcs = [
            "build-openssl.sh",
            "openssl-1.1.1d.tar.gz",
            "patch-conf.patch",
            "patch-include.patch",
        ],
        cmd_bash =
            "mkdir -p $(RULEDIR)/{} && cp $(SRCS) $(RULEDIR)/{}/ && sh $(RULEDIR)/{}/build-openssl.sh $(RULEDIR)/{} $(RULEDIR)/{} ".format(arch, arch, arch, arch, arch) + arch + "\n" +
            ("\n".join(["cp \"$(RULEDIR)/{}/build/arm64/include/openssl/{}\" \"$(location :{})\"\n".format(arch, x, x) for x in openssl_headers]) if arch == "arm64" else "") +
            "\n".join([
                "cp \"$(RULEDIR)/{}/build/{}/lib/{}\" \"$(location :{})\"\n".format(arch, arch, x, arch + "_" + x) for x in openssl_libs
            ]),
        outs =
            (openssl_headers if arch == "arm64" else []) +
            [arch + "_" + x for x in openssl_libs],
        visibility = [
            "//visibility:public",
        ]
    ) for arch in archs
]

genrule(
    name = "openssl_fat_libraries",
    srcs = [":" + arch + "_" + openssl_libs[0] for arch in archs],
    cmd_bash = "xcrun lipo {} -output {} -create".format(" ".join(["$(location :" + arch + "_" + openssl_libs[0] + ")" for arch in archs]), "$(location " + openssl_libs[0] + ")"),
    outs = openssl_libs,
    visibility = [
        "//visibility:public",
    ],
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
        "Public/openssl",
    ],
    deps = [
        ":openssl_lib",
    ],
    ,
    visibility = [
        "//visibility:public",
    ]
)
