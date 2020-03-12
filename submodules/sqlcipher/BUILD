
public_headers = glob([
    "PublicHeaders/**/*.h",
])

objc_library(
    name = "sqlcipher",
    enable_modules = True,
    module_name = "sqlcipher",
    srcs = glob([
        "Sources/*.c",
        "Sources/*.h",
    ], exclude = public_headers),
    hdrs = public_headers,
    includes = [
        "PublicHeaders",
    ],
    copts = [
        "-DDSQLITE_HAS_CODEC=1",
        "-DSQLCIPHER_CRYPTO_CC=1",
        "-DSQLITE_ENABLE_FTS5",
        "-DSQLITE_DEFAULT_MEMSTATUS=0",
        "-DNDEBUG",
    ],
    sdk_frameworks = [
      "Foundation",
      "Security",
    ],
    visibility = [
        "//visibility:public",
    ],
)
