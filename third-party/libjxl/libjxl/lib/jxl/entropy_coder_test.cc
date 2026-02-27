// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// TODO(deymo): Move these tests to dec_ans.h and common.h

#include <stdint.h>

#include "lib/jxl/base/random.h"
#include "lib/jxl/common.h"
#include "lib/jxl/dec_ans.h"
#include "lib/jxl/testing.h"

namespace jxl {
namespace {

TEST(EntropyCoderTest, PackUnpack) {
  for (int32_t i = -31; i < 32; ++i) {
    uint32_t packed = PackSigned(i);
    EXPECT_LT(packed, 63u);
    int32_t unpacked = UnpackSigned(packed);
    EXPECT_EQ(i, unpacked);
  }
}

struct DummyBitReader {
  uint32_t nbits, bits;
  void Consume(uint32_t nbits) {}
  uint32_t PeekBits(uint32_t n) {
    EXPECT_EQ(n, nbits);
    return bits;
  }
};

void HybridUintRoundtrip(HybridUintConfig config, size_t limit = 1 << 24) {
  Rng rng(0);
  constexpr size_t kNumIntegers = 1 << 20;
  std::vector<uint32_t> integers(kNumIntegers);
  std::vector<uint32_t> token(kNumIntegers);
  std::vector<uint32_t> nbits(kNumIntegers);
  std::vector<uint32_t> bits(kNumIntegers);
  for (size_t i = 0; i < kNumIntegers; i++) {
    integers[i] = rng.UniformU(0, limit + 1);
    config.Encode(integers[i], &token[i], &nbits[i], &bits[i]);
  }
  for (size_t i = 0; i < kNumIntegers; i++) {
    DummyBitReader br{nbits[i], bits[i]};
    EXPECT_EQ(integers[i],
              ANSSymbolReader::ReadHybridUintConfig(config, token[i], &br));
  }
}

TEST(HybridUintTest, Test000) {
  HybridUintRoundtrip(HybridUintConfig{0, 0, 0});
}
TEST(HybridUintTest, Test411) {
  HybridUintRoundtrip(HybridUintConfig{4, 1, 1});
}
TEST(HybridUintTest, Test420) {
  HybridUintRoundtrip(HybridUintConfig{4, 2, 0});
}
TEST(HybridUintTest, Test421) {
  HybridUintRoundtrip(HybridUintConfig{4, 2, 1}, 256);
}

}  // namespace
}  // namespace jxl
