
cc_library(
    name = "pffft",
    hdrs = [
        "third_party/pffft/src/pffft.h",
        "third_party/pffft/src/fftpack.h",
    ],
    srcs = [
        "third_party/pffft/src/fftpack.c",
        "third_party/pffft/src/pffft.c",
    ],
    cxxopts = [
        "-std=c++17",
    ],
    deps = [
    ],
    copts = [
    ],
    includes = [
        ".",
    ],
    visibility = ["//visibility:public"],
)
