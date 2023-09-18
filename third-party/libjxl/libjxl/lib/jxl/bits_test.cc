// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/jxl/base/bits.h"

#include "lib/jxl/testing.h"

namespace jxl {
namespace {

TEST(BitsTest, TestNumZeroBits) {
  // Zero input is well-defined.
  EXPECT_EQ(32u, Num0BitsAboveMS1Bit(0u));
  EXPECT_EQ(64u, Num0BitsAboveMS1Bit(0ull));
  EXPECT_EQ(32u, Num0BitsBelowLS1Bit(0u));
  EXPECT_EQ(64u, Num0BitsBelowLS1Bit(0ull));

  EXPECT_EQ(31u, Num0BitsAboveMS1Bit(1u));
  EXPECT_EQ(30u, Num0BitsAboveMS1Bit(2u));
  EXPECT_EQ(63u, Num0BitsAboveMS1Bit(1ull));
  EXPECT_EQ(62u, Num0BitsAboveMS1Bit(2ull));

  EXPECT_EQ(0u, Num0BitsBelowLS1Bit(1u));
  EXPECT_EQ(0u, Num0BitsBelowLS1Bit(1ull));
  EXPECT_EQ(1u, Num0BitsBelowLS1Bit(2u));
  EXPECT_EQ(1u, Num0BitsBelowLS1Bit(2ull));

  EXPECT_EQ(0u, Num0BitsAboveMS1Bit(0x80000000u));
  EXPECT_EQ(0u, Num0BitsAboveMS1Bit(0x8000000000000000ull));
  EXPECT_EQ(31u, Num0BitsBelowLS1Bit(0x80000000u));
  EXPECT_EQ(63u, Num0BitsBelowLS1Bit(0x8000000000000000ull));
}

TEST(BitsTest, TestFloorLog2) {
  // for input = [1, 7]
  const size_t expected[7] = {0, 1, 1, 2, 2, 2, 2};
  for (uint32_t i = 1; i <= 7; ++i) {
    EXPECT_EQ(expected[i - 1], FloorLog2Nonzero(i)) << " " << i;
    EXPECT_EQ(expected[i - 1], FloorLog2Nonzero(uint64_t(i))) << " " << i;
  }

  EXPECT_EQ(11u, FloorLog2Nonzero(0x00000fffu));  // 4095
  EXPECT_EQ(12u, FloorLog2Nonzero(0x00001000u));  // 4096
  EXPECT_EQ(12u, FloorLog2Nonzero(0x00001001u));  // 4097

  EXPECT_EQ(31u, FloorLog2Nonzero(0x80000000u));
  EXPECT_EQ(31u, FloorLog2Nonzero(0x80000001u));
  EXPECT_EQ(31u, FloorLog2Nonzero(0xFFFFFFFFu));

  EXPECT_EQ(31u, FloorLog2Nonzero(0x80000000ull));
  EXPECT_EQ(31u, FloorLog2Nonzero(0x80000001ull));
  EXPECT_EQ(31u, FloorLog2Nonzero(0xFFFFFFFFull));

  EXPECT_EQ(63u, FloorLog2Nonzero(0x8000000000000000ull));
  EXPECT_EQ(63u, FloorLog2Nonzero(0x8000000000000001ull));
  EXPECT_EQ(63u, FloorLog2Nonzero(0xFFFFFFFFFFFFFFFFull));
}

TEST(BitsTest, TestCeilLog2) {
  // for input = [1, 7]
  const size_t expected[7] = {0, 1, 2, 2, 3, 3, 3};
  for (uint32_t i = 1; i <= 7; ++i) {
    EXPECT_EQ(expected[i - 1], CeilLog2Nonzero(i)) << " " << i;
    EXPECT_EQ(expected[i - 1], CeilLog2Nonzero(uint64_t(i))) << " " << i;
  }

  EXPECT_EQ(12u, CeilLog2Nonzero(0x00000fffu));  // 4095
  EXPECT_EQ(12u, CeilLog2Nonzero(0x00001000u));  // 4096
  EXPECT_EQ(13u, CeilLog2Nonzero(0x00001001u));  // 4097

  EXPECT_EQ(31u, CeilLog2Nonzero(0x80000000u));
  EXPECT_EQ(32u, CeilLog2Nonzero(0x80000001u));
  EXPECT_EQ(32u, CeilLog2Nonzero(0xFFFFFFFFu));

  EXPECT_EQ(31u, CeilLog2Nonzero(0x80000000ull));
  EXPECT_EQ(32u, CeilLog2Nonzero(0x80000001ull));
  EXPECT_EQ(32u, CeilLog2Nonzero(0xFFFFFFFFull));

  EXPECT_EQ(63u, CeilLog2Nonzero(0x8000000000000000ull));
  EXPECT_EQ(64u, CeilLog2Nonzero(0x8000000000000001ull));
  EXPECT_EQ(64u, CeilLog2Nonzero(0xFFFFFFFFFFFFFFFFull));
}

}  // namespace
}  // namespace jxl
