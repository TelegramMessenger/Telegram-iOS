
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
        "-DSQLITE_HAS_CODEC=1",
        "-DSQLCIPHER_CRYPTO_CC=1",
        "-DSQLITE_TEMP_STORE=2",
        "-DSQLITE_ENABLE_FTS5",
        "-DHAVE_USLEEP=1",
        "-DSQLITE_DEFAULT_MEMSTATUS=0",
        "-DSQLITE_OMIT_LOAD_EXTENSION",
        "-DSQLITE_OMIT_DECLTYPE",
        "-DSQLITE_OMIT_PROGRESS_CALLBACK",
        "-DSQLITE_OMIT_DEPRECATED",
        "-DNDEBUG=1",
        "-DSQLITE_MAX_MMAP_SIZE=0",
    ],
    sdk_frameworks = [
      "Foundation",
      "Security",
    ],
    visibility = [
        "//visibility:public",
    ],
)
