// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/jxl/coeff_order.h"

#include <stdio.h>

#include <algorithm>
#include <numeric>  // iota
#include <utility>
#include <vector>

#include "lib/jxl/base/printf_macros.h"
#include "lib/jxl/base/random.h"
#include "lib/jxl/base/span.h"
#include "lib/jxl/coeff_order_fwd.h"
#include "lib/jxl/dec_bit_reader.h"
#include "lib/jxl/enc_coeff_order.h"
#include "lib/jxl/testing.h"

namespace jxl {
namespace {

void RoundtripPermutation(coeff_order_t* perm, coeff_order_t* out, size_t len,
                          size_t* size) {
  BitWriter writer;
  EncodePermutation(perm, 0, len, &writer, 0, nullptr);
  writer.ZeroPadToByte();
  Status status = true;
  {
    BitReader reader(writer.GetSpan());
    BitReaderScopedCloser closer(&reader, &status);
    ASSERT_TRUE(DecodePermutation(0, len, out, &reader));
  }
  ASSERT_TRUE(status);
  *size = writer.GetSpan().size();
}

enum Permutation { kIdentity, kFewSwaps, kFewSlides, kRandom };

constexpr size_t kSwaps = 32;

void TestPermutation(Permutation kind, size_t len) {
  std::vector<coeff_order_t> perm(len);
  std::iota(perm.begin(), perm.end(), 0);
  Rng rng(0);
  if (kind == kFewSwaps) {
    for (size_t i = 0; i < kSwaps; i++) {
      size_t a = rng.UniformU(0, len - 1);
      size_t b = rng.UniformU(0, len - 1);
      std::swap(perm[a], perm[b]);
    }
  }
  if (kind == kFewSlides) {
    for (size_t i = 0; i < kSwaps; i++) {
      size_t a = rng.UniformU(0, len - 1);
      size_t b = rng.UniformU(0, len - 1);
      size_t from = std::min(a, b);
      size_t to = std::max(a, b);
      size_t start = perm[from];
      for (size_t j = from; j < to; j++) {
        perm[j] = perm[j + 1];
      }
      perm[to] = start;
    }
  }
  if (kind == kRandom) {
    rng.Shuffle(perm.data(), perm.size());
  }
  std::vector<coeff_order_t> out(len);
  size_t size = 0;
  RoundtripPermutation(perm.data(), out.data(), len, &size);
  for (size_t idx = 0; idx < len; idx++) {
    EXPECT_EQ(perm[idx], out[idx]);
  }
  printf("Encoded size: %" PRIuS "\n", size);
}

TEST(CoeffOrderTest, IdentitySmall) { TestPermutation(kIdentity, 256); }
TEST(CoeffOrderTest, FewSlidesSmall) { TestPermutation(kFewSlides, 256); }
TEST(CoeffOrderTest, FewSwapsSmall) { TestPermutation(kFewSwaps, 256); }
TEST(CoeffOrderTest, RandomSmall) { TestPermutation(kRandom, 256); }

TEST(CoeffOrderTest, IdentityMedium) { TestPermutation(kIdentity, 1 << 12); }
TEST(CoeffOrderTest, FewSlidesMedium) { TestPermutation(kFewSlides, 1 << 12); }
TEST(CoeffOrderTest, FewSwapsMedium) { TestPermutation(kFewSwaps, 1 << 12); }
TEST(CoeffOrderTest, RandomMedium) { TestPermutation(kRandom, 1 << 12); }

TEST(CoeffOrderTest, IdentityBig) { TestPermutation(kIdentity, 1 << 16); }
TEST(CoeffOrderTest, FewSlidesBig) { TestPermutation(kFewSlides, 1 << 16); }
TEST(CoeffOrderTest, FewSwapsBig) { TestPermutation(kFewSwaps, 1 << 16); }
TEST(CoeffOrderTest, RandomBig) { TestPermutation(kRandom, 1 << 16); }

}  // namespace
}  // namespace jxl
