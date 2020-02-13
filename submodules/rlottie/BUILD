
objc_library(
    name = "RLottieBinding",
    module_name = "RLottieBinding",
    enable_modules = True,
    srcs = glob([
        "rlottie/src/**/*.cpp",
        "rlottie/src/**/*.h",
        "rlottie/inc/**/*.h",
    ], exclude = [
        "rlottie/src/vector/vdrawhelper_neon.cpp",
        "rlottie/src/vector/stb/**/*",
        "rlottie/src/lottie/rapidjson/msinttypes/**/*",
    ]) + [
        "LottieInstance.mm",
        "config.h",
    ],
    hdrs = glob([
        "PublicHeaders/**/*.h",
    ]),
    includes = [
        "PublicHeaders",
    ],
    copts = [
        "-Dpixman_region_selfcheck(x)=1",
        "-DLOTTIE_DISABLE_ARM_NEON=1",
        "-Isubmodules/rlottie",
        "-Isubmodules/rlottie/rlottie/inc",
        "-Isubmodules/rlottie/rlottie/src/vector",
        "-Isubmodules/rlottie/rlottie/src/vector/pixman",
        "-Isubmodules/rlottie/rlottie/src/vector/freetype",
    ],
    deps = [
    ],
    visibility = ["//visibility:public"],
)
