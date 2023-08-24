# Copyright (c) the JPEG XL Project Authors. All rights reserved.
#
# Use of this source code is governed by a BSD-style
# license that can be found in the LICENSE file.

# Extra build variables.

libjxl_root_package = "__main__"

libjxl_deps_brotli = ["@brotli//:brotlidec", "@brotli//:brotlienc"]
libjxl_deps_gif = ["@gif//:gif"]
libjxl_deps_gtest = ["@googletest//:gtest_main"]
libjxl_deps_hwy = ["@highway//:hwy"]
libjxl_deps_hwy_nanobenchmark = ["@highway//:nanobenchmark"]
libjxl_deps_hwy_test_util = ["@highway//:hwy_test_util"]
libjxl_deps_jpeg = ["@libjpeg_turbo//:jpeg"]
libjxl_deps_jxl_box = ["//tools:box"]
libjxl_deps_exr = ["@openexr//:OpenEXR"]
libjxl_deps_png = ["@png//:png"]
libjxl_deps_runfiles = ["@bazel_tools//tools/cpp/runfiles"]
libjxl_deps_skcms = ["@skcms//:skcms"]
libjxl_deps_testdata = ["//:testdata"]

libjxl_test_shards = {
    "jpegli/decode_api_test": 10,
    "jpegli/encode_api_test": 4,
    "jpegli/input_suspension_test": 6,
    "jpegli/output_suspension_test": 2,
    "jxl/ans_test": 2,
    "jxl/linalg_test": 2,
    "jxl/modular_test": 4,
    "jxl/roundtrip_test": 4,
    "jxl/xorshift128plus_test": 2,
    "jxl/ac_strategy_test": 10,  # TODO(eustas): separate heavy shard
    "jxl/dct_test": 32,
    "jxl/decode_test": 10,  # TODO(eustas): separate heavy shard
    "jxl/fast_dct_test": 8,  # TODO(eustas): separate ultra-heavy shard
    "jxl/fast_math_test": 10,  # TODO(eustas): separate heavy shard
    "jxl/jxl_test": 10,  # TODO(eustas): separate heavy shard
    "jxl/render_pipeline/render_pipeline_test": 10,
}

libjxl_test_timeouts = {
    "jxl/fast_dct_test": "long",
    "jxl/dct_test": "long",
}
