
config_setting(
    name = "debug_build",
    values = {
        "compilation_mode": "dbg",
    },
)

optimization_flags = select({
    ":debug_build": ["-O2", "-DNDEBUG"],
    "//conditions:default": ["-DNDEBUG"],
})

common_flags = []

arm_specific_flags = [
    "-DLIBYUV_NEON",
]

arm64_specific_flags = [
    "-DLIBYUV_NEON",
]

x86_64_specific_flags = [
    "-DHAVE_SSE2",
]

arch_specific_cflags = select({
    "@build_bazel_rules_apple//apple:ios_armv7": common_flags + arm_specific_flags,
    "@build_bazel_rules_apple//apple:ios_arm64": common_flags + arm64_specific_flags,
    "//build-system:ios_sim_arm64": common_flags + arm64_specific_flags,
    "@build_bazel_rules_apple//apple:ios_x86_64": common_flags + x86_64_specific_flags,
})

cc_library(
    name = "libyuv",
    srcs = [ "third_party/libyuv/" + path for path in [
        # Headers
        "include/libyuv.h",
        "include/libyuv/basic_types.h",
        "include/libyuv/compare.h",
        "include/libyuv/compare_row.h",
        "include/libyuv/convert.h",
        "include/libyuv/convert_argb.h",
        "include/libyuv/convert_from.h",
        "include/libyuv/convert_from_argb.h",
        "include/libyuv/cpu_id.h",
        "include/libyuv/mjpeg_decoder.h",
        "include/libyuv/planar_functions.h",
        "include/libyuv/rotate.h",
        "include/libyuv/rotate_argb.h",
        "include/libyuv/rotate_row.h",
        "include/libyuv/row.h",
        "include/libyuv/scale.h",
        "include/libyuv/scale_argb.h",
        "include/libyuv/scale_row.h",
        "include/libyuv/scale_uv.h",
        "include/libyuv/version.h",
        "include/libyuv/video_common.h",

        # Source Files
        "source/compare.cc",
        "source/compare_common.cc",
        "source/compare_gcc.cc",
        "source/compare_win.cc",
        "source/convert.cc",
        "source/convert_argb.cc",
        "source/convert_from.cc",
        "source/convert_from_argb.cc",
        "source/convert_jpeg.cc",
        "source/convert_to_argb.cc",
        "source/convert_to_i420.cc",
        "source/cpu_id.cc",
        "source/mjpeg_decoder.cc",
        "source/mjpeg_validate.cc",
        "source/planar_functions.cc",
        "source/rotate.cc",
        "source/rotate_any.cc",
        "source/rotate_argb.cc",
        "source/rotate_common.cc",
        "source/rotate_gcc.cc",
        "source/rotate_win.cc",
        "source/row_any.cc",
        "source/row_common.cc",
        "source/row_gcc.cc",
        "source/row_win.cc",
        "source/scale.cc",
        "source/scale_any.cc",
        "source/scale_argb.cc",
        "source/scale_common.cc",
        "source/scale_gcc.cc",
        "source/scale_uv.cc",
        "source/scale_win.cc",
        "source/video_common.cc",

        # ARM Source Files
        "source/compare_neon.cc",
        "source/compare_neon64.cc",
        "source/rotate_neon.cc",
        "source/rotate_neon64.cc",
        "source/row_neon.cc",
        "source/row_neon64.cc",
        "source/scale_neon.cc",
        "source/scale_neon64.cc",
    ]],
    copts = [
        "-ffp-contract=fast",
        "-Ithird-party/libyuv/third_party/libyuv/include",
    ] + arch_specific_cflags + optimization_flags,
    visibility = ["//visibility:public"],
)


objc_library(
    name = "LibYuvBinding",
    enable_modules = True,
    module_name = "LibYuvBinding",
    srcs = glob([
        "LibYuvBinding/Sources/**/*.m",
        "LibYuvBinding/Sources/**/*.c",
        "LibYuvBinding/Sources/**/*.h",
    ]),
    hdrs = glob([
        "LibYuvBinding/PublicHeaders/**/*.h",
    ]),
    includes = [
        "LibYuvBinding/PublicHeaders",
    ],
    copts = [
        "-Ithird-party/libyuv/third_party/libyuv/include",
    ],
    deps = [
        ":libyuv",
    ],
    sdk_frameworks = [
        "Foundation",
    ],
    visibility = [
        "//visibility:public",
    ],
)

