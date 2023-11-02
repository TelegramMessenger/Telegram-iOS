 
objc_library(
    name = "boost_regex",
    enable_modules = True,
    module_name = "boost_regex",
    srcs = glob([
        "Sources/**/*.c",
        "Sources/**/*.cpp",
        "Sources/**/*.h",
        "Sources/**/*.hpp",
    ]),
    hdrs = glob([
        "include/boost_regex/*.h",
    ]),
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
