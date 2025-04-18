// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/jxl/base/byte_order.h"

#include "lib/jxl/testing.h"

namespace jxl {
namespace {

TEST(ByteOrderTest, TestRoundTripBE16) {
  const uint32_t in = 0x1234;
  uint8_t buf[2];
  StoreBE16(in, buf);
  EXPECT_EQ(in, LoadBE16(buf));
  EXPECT_NE(in, LoadLE16(buf));
}

TEST(ByteOrderTest, TestRoundTripLE16) {
  const uint32_t in = 0x1234;
  uint8_t buf[2];
  StoreLE16(in, buf);
  EXPECT_EQ(in, LoadLE16(buf));
  EXPECT_NE(in, LoadBE16(buf));
}

TEST(ByteOrderTest, TestRoundTripBE32) {
  const uint32_t in = 0xFEDCBA98u;
  uint8_t buf[4];
  StoreBE32(in, buf);
  EXPECT_EQ(in, LoadBE32(buf));
  EXPECT_NE(in, LoadLE32(buf));
}

TEST(ByteOrderTest, TestRoundTripLE32) {
  const uint32_t in = 0xFEDCBA98u;
  uint8_t buf[4];
  StoreLE32(in, buf);
  EXPECT_EQ(in, LoadLE32(buf));
  EXPECT_NE(in, LoadBE32(buf));
}

TEST(ByteOrderTest, TestRoundTripLE64) {
  const uint64_t in = 0xFEDCBA9876543210ull;
  uint8_t buf[8];
  StoreLE64(in, buf);
  EXPECT_EQ(in, LoadLE64(buf));
}

}  // namespace
}  // namespace jxl
