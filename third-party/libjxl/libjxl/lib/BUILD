# Copyright (c) the JPEG XL Project Authors. All rights reserved.
#
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

# Load sources/headers/tests lists.
load(
    "jxl_lists.bzl",
    "libjxl_base_sources",
    "libjxl_codec_apng_sources",
    "libjxl_codec_exr_sources",
    "libjxl_codec_gif_sources",
    "libjxl_codec_jpegli_sources",
    "libjxl_codec_jpg_sources",
    "libjxl_codec_jxl_sources",
    "libjxl_codec_npy_sources",
    "libjxl_codec_pgx_sources",
    "libjxl_codec_pnm_sources",
    "libjxl_dec_box_sources",
    "libjxl_dec_jpeg_sources",
    "libjxl_dec_sources",
    "libjxl_enc_sources",
    "libjxl_extras_for_tools_sources",
    "libjxl_extras_sources",
    #'libjxl_gbench_sources',
    "libjxl_jpegli_lib_version",
    "libjxl_jpegli_libjpeg_helper_files",
    "libjxl_jpegli_sources",
    "libjxl_jpegli_testlib_files",
    "libjxl_jpegli_tests",
    "libjxl_major_version",
    "libjxl_minor_version",
    "libjxl_patch_version",
    "libjxl_public_headers",
    "libjxl_testlib_files",
    "libjxl_tests",
    "libjxl_threads_public_headers",
    "libjxl_threads_sources",
)
load(
    "jxl_vars.bzl",
    "libjxl_deps_brotli",
    "libjxl_deps_exr",
    "libjxl_deps_gif",
    "libjxl_deps_gtest",
    "libjxl_deps_hwy",
    "libjxl_deps_hwy_nanobenchmark",
    "libjxl_deps_hwy_test_util",
    "libjxl_deps_jpeg",
    "libjxl_deps_jxl_box",
    "libjxl_deps_png",
    "libjxl_deps_runfiles",
    "libjxl_deps_skcms",
    "libjxl_deps_testdata",
    "libjxl_root_package",
    "libjxl_test_shards",
    "libjxl_test_timeouts",
)
load("@bazel_skylib//rules:expand_template.bzl", "expand_template")
load("@bazel_skylib//rules:copy_file.bzl", "copy_file")

DEFAULT_VISIBILITY = ["//:__subpackages__"]

DEFAULT_COMPATIBILITY = []

INCLUDES_DIR = "include"

package(
    default_visibility = ["//:__subpackages__"],
)

licenses(["notice"])

exports_files(["LICENSE"])

EXPORT_TEMPLATE = """
#ifndef @_EXPORT_H
#define @_EXPORT_H

#define @_EXPORT
#define @_NO_EXPORT

#ifndef @_DEPRECATED
#  define @_DEPRECATED __attribute__ ((__deprecated__))
#endif

#endif
"""

JXL_EXPORT_H = INCLUDES_DIR + "/jxl/jxl_export.h"

genrule(
    name = "create_jxl_export",
    outs = [JXL_EXPORT_H],
    cmd = "echo '" + EXPORT_TEMPLATE.replace("@", "JXL") + "' > $@",
    compatible_with = DEFAULT_COMPATIBILITY,
)

JXL_THREADS_EXPORT_H = INCLUDES_DIR + "/jxl/jxl_threads_export.h"

genrule(
    name = "create_jxl_threads_export",
    outs = [JXL_THREADS_EXPORT_H],
    cmd = "echo '" + EXPORT_TEMPLATE.replace("@", "JXL_THREADS") + "' > $@",
    compatible_with = DEFAULT_COMPATIBILITY,
)

JXL_VERSION_H = INCLUDES_DIR + "/jxl/version.h"

expand_template(
    name = "expand_jxl_version",
    out = JXL_VERSION_H,
    compatible_with = DEFAULT_COMPATIBILITY,
    substitutions = {
        "@JPEGXL_MAJOR_VERSION@": str(libjxl_major_version),
        "@JPEGXL_MINOR_VERSION@": str(libjxl_minor_version),
        "@JPEGXL_PATCH_VERSION@": str(libjxl_patch_version),
    },
    template = "jxl/version.h.in",
)

cc_library(
    name = "jxl_version",
    hdrs = [JXL_VERSION_H],
    compatible_with = DEFAULT_COMPATIBILITY,
    strip_include_prefix = INCLUDES_DIR,
)

JPEGLI_JCONFIG_H = INCLUDES_DIR + "/jpegli/jconfig.h"

JPEGLI_JMORECFG_H = INCLUDES_DIR + "/jpegli/jmorecfg.h"

JPEGLI_JPEGLIB_H = INCLUDES_DIR + "/jpegli/jpeglib.h"

copy_file(
    name = "expand_jconfig",
    src = "@libjpeg_turbo//:jconfig.h",
    out = JPEGLI_JCONFIG_H,
    compatible_with = DEFAULT_COMPATIBILITY,
)

copy_file(
    name = "copy_jmorecfg",
    src = "@libjpeg_turbo//:jmorecfg.h",
    out = JPEGLI_JMORECFG_H,
    compatible_with = DEFAULT_COMPATIBILITY,
)

copy_file(
    name = "copy_jpeglib",
    src = "@libjpeg_turbo//:jpeglib.h",
    out = JPEGLI_JPEGLIB_H,
    compatible_with = DEFAULT_COMPATIBILITY,
)

cc_library(
    name = "includes",
    hdrs = libjxl_public_headers + [JXL_EXPORT_H],
    compatible_with = DEFAULT_COMPATIBILITY,
    strip_include_prefix = INCLUDES_DIR,
    deps = [":jxl_version"],
)

cc_library(
    name = "libjpeg_includes",
    hdrs = [
        JPEGLI_JCONFIG_H,
        JPEGLI_JMORECFG_H,
        JPEGLI_JPEGLIB_H,
    ],
    compatible_with = DEFAULT_COMPATIBILITY,
    strip_include_prefix = INCLUDES_DIR + "/jpegli",
)

cc_library(
    name = "base",
    srcs = [path for path in libjxl_base_sources if path.endswith(".cc")],
    hdrs = [path for path in libjxl_base_sources if path.endswith(".h")],
    compatible_with = DEFAULT_COMPATIBILITY,
    deps = [
        ":includes",
    ] + libjxl_deps_hwy,
)

cc_library(
    name = "jpegxl",
    srcs = libjxl_dec_sources + libjxl_dec_box_sources + libjxl_dec_jpeg_sources + libjxl_enc_sources,
    compatible_with = DEFAULT_COMPATIBILITY,
    defines = ["JPEGXL_ENABLE_SKCMS=1"],
    deps = [
        ":base",
        ":includes",
    ] + libjxl_deps_brotli + libjxl_deps_hwy + libjxl_deps_skcms,
)

cc_library(
    name = "jpegxl_private",
    hdrs = [
        path
        for path in libjxl_dec_sources + libjxl_dec_box_sources + libjxl_dec_jpeg_sources + libjxl_enc_sources
        if path.endswith(".h") and not path.endswith("-inl.h")
    ],
    compatible_with = DEFAULT_COMPATIBILITY,
    deps = [":jpegxl"],
)

cc_library(
    name = "jpegxl_threads",
    srcs = libjxl_threads_sources,
    hdrs = libjxl_threads_public_headers + [JXL_THREADS_EXPORT_H],
    compatible_with = DEFAULT_COMPATIBILITY,
    strip_include_prefix = INCLUDES_DIR,
    deps = [
        ":base",
        ":includes",
    ],
)

CODEC_FILES = libjxl_codec_apng_sources + libjxl_codec_exr_sources + libjxl_codec_gif_sources + libjxl_codec_jpegli_sources + libjxl_codec_jpg_sources + libjxl_codec_jxl_sources + libjxl_codec_npy_sources + libjxl_codec_pgx_sources + libjxl_codec_pnm_sources

CODEC_SRCS = [path for path in CODEC_FILES if path.endswith(".cc")]

CODEC_HDRS = [path for path in CODEC_FILES if path.endswith(".h")]

cc_library(
    name = "jpegli",
    srcs = libjxl_jpegli_sources,
    hdrs = [
        "jpegli/common_internal.h",  # TODO(eustas): should not be here
    ],
    compatible_with = DEFAULT_COMPATIBILITY,
    deps = [
        ":jpegxl_private",
        ":libjpeg_includes",
    ] + libjxl_deps_hwy,
)

# TODO(eustas): build codecs separately?
cc_library(
    name = "jpegxl_extras",
    srcs = libjxl_extras_sources + libjxl_extras_for_tools_sources + CODEC_SRCS,
    hdrs = CODEC_HDRS,
    compatible_with = DEFAULT_COMPATIBILITY,
    defines = [
        "JPEGXL_ENABLE_APNG=1",
        "JPEGXL_ENABLE_EXR=1",
        "JPEGXL_ENABLE_GIF=1",
        "JPEGXL_ENABLE_JPEG=1",
        "JPEGXL_ENABLE_JPEGLI=1",
    ],
    deps = [
        ":jpegli",
        ":jpegxl_private",
        ":jpegxl_threads",
        ":jxl_version",
    ] + libjxl_deps_exr + libjxl_deps_gif + libjxl_deps_jpeg + libjxl_deps_png,
)

TESTLIB_FILES = libjxl_testlib_files + libjxl_jpegli_testlib_files + libjxl_jpegli_libjpeg_helper_files

cc_library(
    name = "test_utils",
    testonly = 1,
    srcs = [path for path in TESTLIB_FILES if not path.endswith(".h")],
    hdrs = [path for path in TESTLIB_FILES if path.endswith(".h")],
    compatible_with = DEFAULT_COMPATIBILITY,
    defines = [
        'JPEGXL_ROOT_PACKAGE=\'"' + libjxl_root_package + '"\'',
    ],
    deps = [
        ":jpegli",
        ":jpegxl_extras",
        ":jpegxl_private",
    ] + libjxl_deps_runfiles,
)

TESTS = [path.partition(".")[0] for path in libjxl_tests + libjxl_jpegli_tests]

[
    cc_test(
        name = test,
        timeout = libjxl_test_timeouts.get(test, "moderate"),
        srcs = [
            test + ".cc",
            "jpegli/testing.h",
            "jxl/testing.h",
        ],
        data = ["//:testdata"],
        shard_count = libjxl_test_shards.get(test, 1),
        deps = [
            ":jpegxl_extras",
            ":jpegxl_private",
            ":jpegxl_threads",
            ":test_utils",
        ] + libjxl_deps_gtest + libjxl_deps_hwy_test_util + libjxl_deps_hwy_nanobenchmark + libjxl_deps_jxl_box,
    )
    for test in TESTS
]
