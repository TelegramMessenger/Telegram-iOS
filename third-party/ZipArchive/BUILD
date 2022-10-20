 
objc_library(
    name = "ZipArchive",
    enable_modules = True,
    module_name = "ZipArchive",
    srcs = glob([
        "Sources/*.m",
        "Sources/minizip/*.h",
        "Sources/minizip/*.c",
    ]),
    hdrs = glob([
        "PublicHeaders/**/*.h",
    ]),
    includes = [
      "PublicHeaders",
    ],
    copts = [
        "-DHAVE_ZLIB",
        "-DHAVE_INTTYPES_H",
        "-DHAVE_PKCRYPT",
        "-DHAVE_STDINT_H",
        "-DHAVE_WZAES",
    ],
    sdk_frameworks = [
      "Foundation",
    ],
    visibility = [
        "//visibility:public",
    ],
)
