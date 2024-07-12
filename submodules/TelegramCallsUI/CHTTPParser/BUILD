
objc_library(
    name = "CHTTPParser",
    enable_modules = True,
    module_name = "CHTTPParser",
    srcs = glob([
        "Sources/**/*.c",
        "Sources/**/*.h",
    ]),
    hdrs = glob([
        "PublicHeaders/**/*.h",
    ]),
    includes = [
        "PublicHeaders",
    ],
    copts = [
        "-I{}/PublicHeaders/CHTTPParser".format(package_name()),
    ],
    sdk_frameworks = [
        "Foundation",
    ],
    visibility = [
        "//visibility:public",
    ],
)
