
load("@rules_cc//cc:objc_library.bzl", "objc_library")

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
    ], exclude = public_headers, allow_empty=True),
    hdrs = public_headers,
    includes = [
        "PublicHeaders",
    ],
    copts = [
        "-DSQLITE_HAS_CODEC=1",
        "-DSQLCIPHER_CRYPTO_CC=1",
        # Required since SQLCipher 4.6: sqlcipher.c #errors without these.
        "-DSQLITE_EXTRA_INIT=sqlcipher_extra_init",
        "-DSQLITE_EXTRA_SHUTDOWN=sqlcipher_extra_shutdown",
        "-DSQLITE_THREADSAFE=1",
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
        "-Wno-all",
        "-Wno-#warnings",
        # sqlite3.c defines MIN/MAX itself; with modules on, Foundation pulls in
        # <sys/param.h>'s textually different MIN/MAX, and clang warns at every
        # use. The pristine amalgamation is kept unpatched (the 2021 copy had a
        # hand edit normalising these macros); suppress the warning instead.
        "-Wno-ambiguous-macro",
    ],
    sdk_frameworks = [
      "Foundation",
      "Security",
    ],
    visibility = [
        "//visibility:public",
    ],
)
