// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include <stdlib.h>

#include <algorithm>

#include "lib/jxl/enc_gamma_correct.h"
#include "lib/jxl/testing.h"

namespace jxl {
namespace {

TEST(GammaCorrectTest, TestLinearToSrgbEdgeCases) {
  EXPECT_EQ(0, LinearToSrgb8Direct(0.0));
  EXPECT_NEAR(0, LinearToSrgb8Direct(1E-6f), 2E-5);
  EXPECT_EQ(0, LinearToSrgb8Direct(-1E-6f));
  EXPECT_EQ(0, LinearToSrgb8Direct(-1E6));
  EXPECT_NEAR(1, LinearToSrgb8Direct(1 - 1E-6f), 1E-5);
  EXPECT_EQ(1, LinearToSrgb8Direct(1 + 1E-6f));
  EXPECT_EQ(1, LinearToSrgb8Direct(1E6));
}

TEST(GammaCorrectTest, TestRoundTrip) {
  // NOLINTNEXTLINE(clang-analyzer-security.FloatLoopCounter)
  for (double linear = 0.0; linear <= 1.0; linear += 1E-7) {
    const double srgb = LinearToSrgb8Direct(linear);
    const double linear2 = Srgb8ToLinearDirect(srgb);
    ASSERT_LT(std::abs(linear - linear2), 2E-13)
        << "linear = " << linear << ", linear2 = " << linear2;
  }
}

}  // namespace
}  // namespace jxl
