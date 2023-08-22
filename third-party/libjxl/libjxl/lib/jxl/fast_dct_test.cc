// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include <stdio.h>

#include <numeric>

#undef HWY_TARGET_INCLUDE
#define HWY_TARGET_INCLUDE "lib/jxl/fast_dct_test.cc"
#include <hwy/foreach_target.h>

#include "lib/jxl/base/random.h"
#include "lib/jxl/dct-inl.h"
#include "lib/jxl/fast_dct-inl.h"
#include "lib/jxl/fast_dct.h"
#include "lib/jxl/transpose-inl.h"

// Test utils
#include <hwy/highway.h>
#include <hwy/tests/test_util-inl.h>
HWY_BEFORE_NAMESPACE();
namespace jxl {
namespace HWY_NAMESPACE {
namespace {

template <size_t N, size_t M>
HWY_NOINLINE void TestFastTranspose() {
#if HWY_TARGET == HWY_NEON
  auto array_mem = hwy::AllocateAligned<int16_t>(N * M);
  int16_t* array = array_mem.get();
  auto transposed_mem = hwy::AllocateAligned<int16_t>(N * M);
  int16_t* transposed = transposed_mem.get();
  std::iota(array, array + N * M, 0);
  for (size_t j = 0; j < 100000000 / (N * M); j++) {
    FastTransposeBlock(array, M, N, M, transposed, N);
  }
  for (size_t i = 0; i < M; i++) {
    for (size_t j = 0; j < N; j++) {
      EXPECT_EQ(array[j * M + i], transposed[i * N + j]);
    }
  }
#endif
}

template <size_t N, size_t M>
HWY_NOINLINE void TestFloatTranspose() {
  auto array_mem = hwy::AllocateAligned<float>(N * M);
  float* array = array_mem.get();
  auto transposed_mem = hwy::AllocateAligned<float>(N * M);
  float* transposed = transposed_mem.get();
  std::iota(array, array + N * M, 0);
  for (size_t j = 0; j < 100000000 / (N * M); j++) {
    Transpose<N, M>::Run(DCTFrom(array, M), DCTTo(transposed, N));
  }
  for (size_t i = 0; i < M; i++) {
    for (size_t j = 0; j < N; j++) {
      EXPECT_EQ(array[j * M + i], transposed[i * N + j]);
    }
  }
}

// TODO(sboukortt): re-enable the FloatIDCT tests once we find out why they fail
// in ASAN mode in the CI runners and seemingly not locally.

HWY_NOINLINE void TestFastTranspose8x8() { TestFastTranspose<8, 8>(); }
HWY_NOINLINE void TestFloatTranspose8x8() { TestFloatTranspose<8, 8>(); }
HWY_NOINLINE void TestFastIDCT8x8() { TestFastIDCT<8, 8>(); }
HWY_NOINLINE void TestFloatIDCT8x8() {
#if HWY_TARGET == HWY_SCALAR && \
    (defined(ADDRESS_SANITIZER) || defined(MEMORY_SANITIZER))
  GTEST_SKIP();
#else
  TestFloatIDCT<8, 8>();
#endif
}
HWY_NOINLINE void TestFastTranspose8x16() { TestFastTranspose<8, 16>(); }
HWY_NOINLINE void TestFloatTranspose8x16() { TestFloatTranspose<8, 16>(); }
HWY_NOINLINE void TestFastIDCT8x16() { TestFastIDCT<8, 16>(); }
HWY_NOINLINE void TestFloatIDCT8x16() {
#if HWY_TARGET == HWY_SCALAR && \
    (defined(ADDRESS_SANITIZER) || defined(MEMORY_SANITIZER))
  GTEST_SKIP();
#else
  TestFloatIDCT<8, 16>();
#endif
}
HWY_NOINLINE void TestFastTranspose8x32() { TestFastTranspose<8, 32>(); }
HWY_NOINLINE void TestFloatTranspose8x32() { TestFloatTranspose<8, 32>(); }
HWY_NOINLINE void TestFastIDCT8x32() { TestFastIDCT<8, 32>(); }
HWY_NOINLINE void TestFloatIDCT8x32() {
#if HWY_TARGET == HWY_SCALAR && \
    (defined(ADDRESS_SANITIZER) || defined(MEMORY_SANITIZER))
  GTEST_SKIP();
#else
  TestFloatIDCT<8, 32>();
#endif
}
HWY_NOINLINE void TestFastTranspose16x8() { TestFastTranspose<16, 8>(); }
HWY_NOINLINE void TestFloatTranspose16x8() { TestFloatTranspose<16, 8>(); }
HWY_NOINLINE void TestFastIDCT16x8() { TestFastIDCT<16, 8>(); }
HWY_NOINLINE void TestFloatIDCT16x8() {
#if HWY_TARGET == HWY_SCALAR && \
    (defined(ADDRESS_SANITIZER) || defined(MEMORY_SANITIZER))
  GTEST_SKIP();
#else
  TestFloatIDCT<16, 8>();
#endif
}
HWY_NOINLINE void TestFastTranspose16x16() { TestFastTranspose<16, 16>(); }
HWY_NOINLINE void TestFloatTranspose16x16() { TestFloatTranspose<16, 16>(); }
HWY_NOINLINE void TestFastIDCT16x16() { TestFastIDCT<16, 16>(); }
HWY_NOINLINE void TestFloatIDCT16x16() {
#if HWY_TARGET == HWY_SCALAR && \
    (defined(ADDRESS_SANITIZER) || defined(MEMORY_SANITIZER))
  GTEST_SKIP();
#else
  TestFloatIDCT<16, 16>();
#endif
}
HWY_NOINLINE void TestFastTranspose16x32() { TestFastTranspose<16, 32>(); }
HWY_NOINLINE void TestFloatTranspose16x32() { TestFloatTranspose<16, 32>(); }
HWY_NOINLINE void TestFastIDCT16x32() { TestFastIDCT<16, 32>(); }
HWY_NOINLINE void TestFloatIDCT16x32() {
#if HWY_TARGET == HWY_SCALAR && \
    (defined(ADDRESS_SANITIZER) || defined(MEMORY_SANITIZER))
  GTEST_SKIP();
#else
  TestFloatIDCT<16, 32>();
#endif
}
HWY_NOINLINE void TestFastTranspose32x8() { TestFastTranspose<32, 8>(); }
HWY_NOINLINE void TestFloatTranspose32x8() { TestFloatTranspose<32, 8>(); }
HWY_NOINLINE void TestFastIDCT32x8() { TestFastIDCT<32, 8>(); }
HWY_NOINLINE void TestFloatIDCT32x8() {
#if HWY_TARGET == HWY_SCALAR && \
    (defined(ADDRESS_SANITIZER) || defined(MEMORY_SANITIZER))
  GTEST_SKIP();
#else
  TestFloatIDCT<32, 8>();
#endif
}
HWY_NOINLINE void TestFastTranspose32x16() { TestFastTranspose<32, 16>(); }
HWY_NOINLINE void TestFloatTranspose32x16() { TestFloatTranspose<32, 16>(); }
HWY_NOINLINE void TestFastIDCT32x16() { TestFastIDCT<32, 16>(); }
HWY_NOINLINE void TestFloatIDCT32x16() {
#if HWY_TARGET == HWY_SCALAR && \
    (defined(ADDRESS_SANITIZER) || defined(MEMORY_SANITIZER))
  GTEST_SKIP();
#else
  TestFloatIDCT<32, 16>();
#endif
}
HWY_NOINLINE void TestFastTranspose32x32() { TestFastTranspose<32, 32>(); }
HWY_NOINLINE void TestFloatTranspose32x32() { TestFloatTranspose<32, 32>(); }
HWY_NOINLINE void TestFastIDCT32x32() { TestFastIDCT<32, 32>(); }
HWY_NOINLINE void TestFloatIDCT32x32() {
#if HWY_TARGET == HWY_SCALAR && \
    (defined(ADDRESS_SANITIZER) || defined(MEMORY_SANITIZER))
  GTEST_SKIP();
#else
  TestFloatIDCT<32, 32>();
#endif
}
HWY_NOINLINE void TestFastTranspose32x64() { TestFastTranspose<32, 64>(); }
HWY_NOINLINE void TestFloatTranspose32x64() { TestFloatTranspose<32, 64>(); }
HWY_NOINLINE void TestFastIDCT32x64() { TestFastIDCT<32, 64>(); }
HWY_NOINLINE void TestFloatIDCT32x64() {
#if HWY_TARGET == HWY_SCALAR && \
    (defined(ADDRESS_SANITIZER) || defined(MEMORY_SANITIZER))
  GTEST_SKIP();
#else
  TestFloatIDCT<32, 64>();
#endif
}
HWY_NOINLINE void TestFastTranspose64x32() { TestFastTranspose<64, 32>(); }
HWY_NOINLINE void TestFloatTranspose64x32() { TestFloatTranspose<64, 32>(); }
HWY_NOINLINE void TestFastIDCT64x32() { TestFastIDCT<64, 32>(); }
HWY_NOINLINE void TestFloatIDCT64x32() {
#if HWY_TARGET == HWY_SCALAR && \
    (defined(ADDRESS_SANITIZER) || defined(MEMORY_SANITIZER))
  GTEST_SKIP();
#else
  TestFloatIDCT<64, 32>();
#endif
}
HWY_NOINLINE void TestFastTranspose64x64() { TestFastTranspose<64, 64>(); }
HWY_NOINLINE void TestFloatTranspose64x64() { TestFloatTranspose<64, 64>(); }
HWY_NOINLINE void TestFastIDCT64x64() { TestFastIDCT<64, 64>(); }
HWY_NOINLINE void TestFloatIDCT64x64() {
#if HWY_TARGET == HWY_SCALAR && \
    (defined(ADDRESS_SANITIZER) || defined(MEMORY_SANITIZER))
  GTEST_SKIP();
#else
  TestFloatIDCT<64, 64>();
#endif
}
HWY_NOINLINE void TestFastTranspose64x128() { TestFastTranspose<64, 128>(); }
HWY_NOINLINE void TestFloatTranspose64x128() { TestFloatTranspose<64, 128>(); }
/*
HWY_NOINLINE void TestFastIDCT64x128() { TestFastIDCT<64, 128>(); }
HWY_NOINLINE void TestFloatIDCT64x128() {
#if HWY_TARGET == HWY_SCALAR && \
    (defined(ADDRESS_SANITIZER) || defined(MEMORY_SANITIZER))
  GTEST_SKIP();
#else
  TestFloatIDCT<64, 128>();
#endif
}
*/
HWY_NOINLINE void TestFastTranspose128x64() { TestFastTranspose<128, 64>(); }
HWY_NOINLINE void TestFloatTranspose128x64() { TestFloatTranspose<128, 64>(); }
/*
HWY_NOINLINE void TestFastIDCT128x64() { TestFastIDCT<128, 64>(); }
HWY_NOINLINE void TestFloatIDCT128x64() {
#if HWY_TARGET == HWY_SCALAR && \
    (defined(ADDRESS_SANITIZER) || defined(MEMORY_SANITIZER))
  GTEST_SKIP();
#else
  TestFloatIDCT<128, 64>();
#endif
}
*/
HWY_NOINLINE void TestFastTranspose128x128() { TestFastTranspose<128, 128>(); }
HWY_NOINLINE void TestFloatTranspose128x128() {
  TestFloatTranspose<128, 128>();
}
/*
HWY_NOINLINE void TestFastIDCT128x128() { TestFastIDCT<128, 128>(); }
HWY_NOINLINE void TestFloatIDCT128x128() {
#if HWY_TARGET == HWY_SCALAR && \
    (defined(ADDRESS_SANITIZER) || defined(MEMORY_SANITIZER))
  GTEST_SKIP();
#else
  TestFloatIDCT<128, 128>();
#endif
}
*/
HWY_NOINLINE void TestFastTranspose128x256() { TestFastTranspose<128, 256>(); }
HWY_NOINLINE void TestFloatTranspose128x256() {
  TestFloatTranspose<128, 256>();
}
/*
HWY_NOINLINE void TestFastIDCT128x256() { TestFastIDCT<128, 256>(); }
HWY_NOINLINE void TestFloatIDCT128x256() {
#if HWY_TARGET == HWY_SCALAR && \
    (defined(ADDRESS_SANITIZER) || defined(MEMORY_SANITIZER))
  GTEST_SKIP();
#else
  TestFloatIDCT<128, 256>();
#endif
}
*/
HWY_NOINLINE void TestFastTranspose256x128() { TestFastTranspose<256, 128>(); }
HWY_NOINLINE void TestFloatTranspose256x128() {
  TestFloatTranspose<256, 128>();
}
/*
HWY_NOINLINE void TestFastIDCT256x128() { TestFastIDCT<256, 128>(); }
HWY_NOINLINE void TestFloatIDCT256x128() {
#if HWY_TARGET == HWY_SCALAR && \
    (defined(ADDRESS_SANITIZER) || defined(MEMORY_SANITIZER))
  GTEST_SKIP();
#else
  TestFloatIDCT<256, 128>();
#endif
}
*/
HWY_NOINLINE void TestFastTranspose256x256() { TestFastTranspose<256, 256>(); }
HWY_NOINLINE void TestFloatTranspose256x256() {
  TestFloatTranspose<256, 256>();
}
/*
HWY_NOINLINE void TestFastIDCT256x256() { TestFastIDCT<256, 256>(); }
HWY_NOINLINE void TestFloatIDCT256x256() {
#if HWY_TARGET == HWY_SCALAR && \
    (defined(ADDRESS_SANITIZER) || defined(MEMORY_SANITIZER))
  GTEST_SKIP();
#else
  TestFloatIDCT<256, 256>();
#endif
}
*/

}  // namespace
// NOLINTNEXTLINE(google-readability-namespace-comments)
}  // namespace HWY_NAMESPACE
}  // namespace jxl
HWY_AFTER_NAMESPACE();

#if HWY_ONCE
namespace jxl {

class FastDCTTargetTest : public hwy::TestWithParamTarget {};
HWY_TARGET_INSTANTIATE_TEST_SUITE_P(FastDCTTargetTest);

HWY_EXPORT_AND_TEST_P(FastDCTTargetTest, TestFloatTranspose8x8);
HWY_EXPORT_AND_TEST_P(FastDCTTargetTest, TestFastTranspose8x8);
HWY_EXPORT_AND_TEST_P(FastDCTTargetTest, TestFloatTranspose8x16);
HWY_EXPORT_AND_TEST_P(FastDCTTargetTest, TestFastTranspose8x16);
HWY_EXPORT_AND_TEST_P(FastDCTTargetTest, TestFloatTranspose8x32);
HWY_EXPORT_AND_TEST_P(FastDCTTargetTest, TestFastTranspose8x32);
HWY_EXPORT_AND_TEST_P(FastDCTTargetTest, TestFloatTranspose16x8);
HWY_EXPORT_AND_TEST_P(FastDCTTargetTest, TestFastTranspose16x8);
HWY_EXPORT_AND_TEST_P(FastDCTTargetTest, TestFloatTranspose16x16);
HWY_EXPORT_AND_TEST_P(FastDCTTargetTest, TestFastTranspose16x16);
HWY_EXPORT_AND_TEST_P(FastDCTTargetTest, TestFloatTranspose16x32);
HWY_EXPORT_AND_TEST_P(FastDCTTargetTest, TestFastTranspose16x32);
HWY_EXPORT_AND_TEST_P(FastDCTTargetTest, TestFloatTranspose32x8);
HWY_EXPORT_AND_TEST_P(FastDCTTargetTest, TestFastTranspose32x8);
HWY_EXPORT_AND_TEST_P(FastDCTTargetTest, TestFloatTranspose32x16);
HWY_EXPORT_AND_TEST_P(FastDCTTargetTest, TestFastTranspose32x16);
HWY_EXPORT_AND_TEST_P(FastDCTTargetTest, TestFloatTranspose32x32);
HWY_EXPORT_AND_TEST_P(FastDCTTargetTest, TestFastTranspose32x32);
HWY_EXPORT_AND_TEST_P(FastDCTTargetTest, TestFloatTranspose32x64);
HWY_EXPORT_AND_TEST_P(FastDCTTargetTest, TestFastTranspose32x64);
HWY_EXPORT_AND_TEST_P(FastDCTTargetTest, TestFloatTranspose64x32);
HWY_EXPORT_AND_TEST_P(FastDCTTargetTest, TestFastTranspose64x32);
HWY_EXPORT_AND_TEST_P(FastDCTTargetTest, TestFloatTranspose64x64);
HWY_EXPORT_AND_TEST_P(FastDCTTargetTest, TestFastTranspose64x64);
HWY_EXPORT_AND_TEST_P(FastDCTTargetTest, TestFloatTranspose64x128);
HWY_EXPORT_AND_TEST_P(FastDCTTargetTest, TestFastTranspose64x128);
HWY_EXPORT_AND_TEST_P(FastDCTTargetTest, TestFloatTranspose128x64);
HWY_EXPORT_AND_TEST_P(FastDCTTargetTest, TestFastTranspose128x64);
HWY_EXPORT_AND_TEST_P(FastDCTTargetTest, TestFloatTranspose128x128);
HWY_EXPORT_AND_TEST_P(FastDCTTargetTest, TestFastTranspose128x128);
HWY_EXPORT_AND_TEST_P(FastDCTTargetTest, TestFloatTranspose128x256);
HWY_EXPORT_AND_TEST_P(FastDCTTargetTest, TestFastTranspose128x256);
HWY_EXPORT_AND_TEST_P(FastDCTTargetTest, TestFloatTranspose256x128);
HWY_EXPORT_AND_TEST_P(FastDCTTargetTest, TestFastTranspose256x128);
HWY_EXPORT_AND_TEST_P(FastDCTTargetTest, TestFloatTranspose256x256);
HWY_EXPORT_AND_TEST_P(FastDCTTargetTest, TestFastTranspose256x256);
HWY_EXPORT_AND_TEST_P(FastDCTTargetTest, TestFloatIDCT8x8);
HWY_EXPORT_AND_TEST_P(FastDCTTargetTest, TestFastIDCT8x8);
HWY_EXPORT_AND_TEST_P(FastDCTTargetTest, TestFloatIDCT8x16);
HWY_EXPORT_AND_TEST_P(FastDCTTargetTest, TestFastIDCT8x16);
HWY_EXPORT_AND_TEST_P(FastDCTTargetTest, TestFloatIDCT8x32);
HWY_EXPORT_AND_TEST_P(FastDCTTargetTest, TestFastIDCT8x32);
HWY_EXPORT_AND_TEST_P(FastDCTTargetTest, TestFloatIDCT16x8);
HWY_EXPORT_AND_TEST_P(FastDCTTargetTest, TestFastIDCT16x8);
HWY_EXPORT_AND_TEST_P(FastDCTTargetTest, TestFloatIDCT16x16);
HWY_EXPORT_AND_TEST_P(FastDCTTargetTest, TestFastIDCT16x16);
HWY_EXPORT_AND_TEST_P(FastDCTTargetTest, TestFloatIDCT16x32);
HWY_EXPORT_AND_TEST_P(FastDCTTargetTest, TestFastIDCT16x32);
HWY_EXPORT_AND_TEST_P(FastDCTTargetTest, TestFloatIDCT32x8);
HWY_EXPORT_AND_TEST_P(FastDCTTargetTest, TestFastIDCT32x8);
HWY_EXPORT_AND_TEST_P(FastDCTTargetTest, TestFloatIDCT32x16);
HWY_EXPORT_AND_TEST_P(FastDCTTargetTest, TestFastIDCT32x16);
HWY_EXPORT_AND_TEST_P(FastDCTTargetTest, TestFloatIDCT32x32);
HWY_EXPORT_AND_TEST_P(FastDCTTargetTest, TestFastIDCT32x32);
HWY_EXPORT_AND_TEST_P(FastDCTTargetTest, TestFloatIDCT32x64);
HWY_EXPORT_AND_TEST_P(FastDCTTargetTest, TestFastIDCT32x64);
HWY_EXPORT_AND_TEST_P(FastDCTTargetTest, TestFloatIDCT64x32);
HWY_EXPORT_AND_TEST_P(FastDCTTargetTest, TestFastIDCT64x32);
HWY_EXPORT_AND_TEST_P(FastDCTTargetTest, TestFloatIDCT64x64);
HWY_EXPORT_AND_TEST_P(FastDCTTargetTest, TestFastIDCT64x64);
/*
 * DCT-128 and above have very large errors just by rounding inputs.
HWY_EXPORT_AND_TEST_P(FastDCTTargetTest, TestFloatIDCT64x128);
HWY_EXPORT_AND_TEST_P(FastDCTTargetTest, TestFastIDCT64x128);
HWY_EXPORT_AND_TEST_P(FastDCTTargetTest, TestFloatIDCT128x64);
HWY_EXPORT_AND_TEST_P(FastDCTTargetTest, TestFastIDCT128x64);
HWY_EXPORT_AND_TEST_P(FastDCTTargetTest, TestFloatIDCT128x128);
HWY_EXPORT_AND_TEST_P(FastDCTTargetTest, TestFastIDCT128x128);
HWY_EXPORT_AND_TEST_P(FastDCTTargetTest, TestFloatIDCT128x256);
HWY_EXPORT_AND_TEST_P(FastDCTTargetTest, TestFastIDCT128x256);
HWY_EXPORT_AND_TEST_P(FastDCTTargetTest, TestFloatIDCT256x128);
HWY_EXPORT_AND_TEST_P(FastDCTTargetTest, TestFastIDCT256x128);
HWY_EXPORT_AND_TEST_P(FastDCTTargetTest, TestFloatIDCT256x256);
HWY_EXPORT_AND_TEST_P(FastDCTTargetTest, TestFastIDCT256x256);
*/

TEST(FastDCTTest, TestWrapperFloat) { BenchmarkFloatIDCT32x32(); }
TEST(FastDCTTest, TestWrapperFast) { BenchmarkFastIDCT32x32(); }

}  // namespace jxl
#endif  // HWY_ONCE
