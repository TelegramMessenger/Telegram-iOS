// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include <stdio.h>

#undef HWY_TARGET_INCLUDE
#define HWY_TARGET_INCLUDE "lib/jxl/simd_util_test.cc"
#include <hwy/foreach_target.h>

#include "lib/jxl/simd_util-inl.h"

// Test utils
#include <hwy/highway.h>
#include <hwy/tests/test_util-inl.h>
HWY_BEFORE_NAMESPACE();
namespace jxl {
namespace HWY_NAMESPACE {
namespace {

HWY_NOINLINE void TestInterleave2() {
  HWY_FULL(float) d;
  auto vec1 = Iota(d, 0 * 128.0);
  auto vec2 = Iota(d, 1 * 128.0);
  HWY_ALIGN float mem[MaxLanes(d) * 2];
  StoreInterleaved(d, vec1, vec2, mem);
  for (size_t i = 0; i < Lanes(d); i++) {
    for (size_t j = 0; j < 2; j++) {
      EXPECT_EQ(mem[2 * i + j], j * 128 + i) << "i: " << i << " j: " << j;
    }
  }
}
HWY_NOINLINE void TestInterleave4() {
  HWY_FULL(float) d;
  auto vec1 = Iota(d, 0 * 128.0);
  auto vec2 = Iota(d, 1 * 128.0);
  auto vec3 = Iota(d, 2 * 128.0);
  auto vec4 = Iota(d, 3 * 128.0);
  HWY_ALIGN float mem[MaxLanes(d) * 4];
  StoreInterleaved(d, vec1, vec2, vec3, vec4, mem);
  for (size_t i = 0; i < Lanes(d); i++) {
    for (size_t j = 0; j < 4; j++) {
      EXPECT_EQ(mem[4 * i + j], j * 128 + i) << "i: " << i << " j: " << j;
    }
  }
}
HWY_NOINLINE void TestInterleave8() {
  HWY_FULL(float) d;
  auto vec1 = Iota(d, 0 * 128.0);
  auto vec2 = Iota(d, 1 * 128.0);
  auto vec3 = Iota(d, 2 * 128.0);
  auto vec4 = Iota(d, 3 * 128.0);
  auto vec5 = Iota(d, 4 * 128.0);
  auto vec6 = Iota(d, 5 * 128.0);
  auto vec7 = Iota(d, 6 * 128.0);
  auto vec8 = Iota(d, 7 * 128.0);
  HWY_ALIGN float mem[MaxLanes(d) * 8];
  StoreInterleaved(d, vec1, vec2, vec3, vec4, vec5, vec6, vec7, vec8, mem);
  for (size_t i = 0; i < Lanes(d); i++) {
    for (size_t j = 0; j < 8; j++) {
      EXPECT_EQ(mem[8 * i + j], j * 128 + i) << "i: " << i << " j: " << j;
    }
  }
}

}  // namespace
// NOLINTNEXTLINE(google-readability-namespace-comments)
}  // namespace HWY_NAMESPACE
}  // namespace jxl
HWY_AFTER_NAMESPACE();

#if HWY_ONCE
namespace jxl {

class SimdUtilTargetTest : public hwy::TestWithParamTarget {};
HWY_TARGET_INSTANTIATE_TEST_SUITE_P(SimdUtilTargetTest);

HWY_EXPORT_AND_TEST_P(SimdUtilTargetTest, TestInterleave2);
HWY_EXPORT_AND_TEST_P(SimdUtilTargetTest, TestInterleave4);
HWY_EXPORT_AND_TEST_P(SimdUtilTargetTest, TestInterleave8);

}  // namespace jxl
#endif  // HWY_ONCE
