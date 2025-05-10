 
objc_library(
    name = "boost_regex",
    enable_modules = True,
    module_name = "boost_regex",
    srcs = glob([
        "Sources/**/*.c",
        "Sources/**/*.cpp",
        "Sources/**/*.h",
        "Sources/**/*.hpp",
    ], allow_empty=True),
    hdrs = glob([
        "include/boost_regex/*.h",
    ], allow_empty=True),
    includes = [
        "include",
    ],
    copts = [
        "-Ithird-party/boost_regex/include",
    ],
    deps = [
    ],
    visibility = [
        "//visibility:public",
    ],
)
