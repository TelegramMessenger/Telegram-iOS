
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
        "-DLOTTIE_THREAD_SAFE=1",
        "-DLOTTIE_IMAGE_MODULE_DISABLED=1",
        "-I{}".format(package_name()),
        "-I{}/rlottie/inc".format(package_name()),
        "-I{}/rlottie/src/vector".format(package_name()),
        "-I{}/rlottie/src/vector/pixman".format(package_name()),
        "-I{}/rlottie/src/vector/freetype".format(package_name()),
    ],
    deps = [
    ],
    visibility = ["//visibility:public"],
)
