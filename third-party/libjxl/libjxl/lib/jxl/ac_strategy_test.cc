// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/jxl/ac_strategy.h"

#include <string.h>

#include <cmath>
#include <hwy/aligned_allocator.h>
#include <hwy/base.h>  // HWY_ALIGN_MAX
#include <hwy/tests/test_util-inl.h>
#include <utility>

#include "lib/jxl/base/random.h"
#include "lib/jxl/common.h"
#include "lib/jxl/dct_scales.h"
#include "lib/jxl/dec_transforms_testonly.h"
#include "lib/jxl/enc_transforms.h"

namespace jxl {
namespace {

// Test that DCT -> IDCT is a noop.
class AcStrategyRoundtrip : public ::hwy::TestWithParamTargetAndT<int> {
 protected:
  void Run() {
    const AcStrategy::Type type = static_cast<AcStrategy::Type>(GetParam());
    const AcStrategy acs = AcStrategy::FromRawStrategy(type);

    auto mem = hwy::AllocateAligned<float>(4 * AcStrategy::kMaxCoeffArea);
    float* scratch_space = mem.get();
    float* coeffs = scratch_space + AcStrategy::kMaxCoeffArea;
    float* idct = coeffs + AcStrategy::kMaxCoeffArea;
    Rng rng(type * 65537 + 13);

    for (size_t j = 0; j < 64; j++) {
      size_t i = (acs.log2_covered_blocks()
                      ? rng.UniformU(0, 64u << acs.log2_covered_blocks())
                      : j);
      float* input = idct + AcStrategy::kMaxCoeffArea;
      std::fill_n(input, AcStrategy::kMaxCoeffArea, 0);
      input[i] = 0.2f;
      TransformFromPixels(type, input, acs.covered_blocks_x() * 8, coeffs,
                          scratch_space);
      ASSERT_NEAR(coeffs[0], 0.2 / (64 << acs.log2_covered_blocks()), 1e-6)
          << " i = " << i;
      TransformToPixels(type, coeffs, idct, acs.covered_blocks_x() * 8,
                        scratch_space);
      for (size_t j = 0; j < 64u << acs.log2_covered_blocks(); j++) {
        ASSERT_NEAR(idct[j], j == i ? 0.2f : 0, 2e-6)
            << "j = " << j << " i = " << i << " acs " << type;
      }
    }
    // Test DC.
    std::fill_n(idct, AcStrategy::kMaxCoeffArea, 0);
    for (size_t y = 0; y < acs.covered_blocks_y(); y++) {
      for (size_t x = 0; x < acs.covered_blocks_x(); x++) {
        float* dc = idct + AcStrategy::kMaxCoeffArea;
        std::fill_n(dc, AcStrategy::kMaxCoeffArea, 0);
        dc[y * acs.covered_blocks_x() * 8 + x] = 0.2;
        LowestFrequenciesFromDC(type, dc, acs.covered_blocks_x() * 8, coeffs,
                                scratch_space);
        DCFromLowestFrequencies(type, coeffs, idct, acs.covered_blocks_x() * 8);
        std::fill_n(dc, AcStrategy::kMaxCoeffArea, 0);
        dc[y * acs.covered_blocks_x() * 8 + x] = 0.2;
        for (size_t j = 0; j < 64u << acs.log2_covered_blocks(); j++) {
          ASSERT_NEAR(idct[j], dc[j], 1e-6)
              << "j = " << j << " x = " << x << " y = " << y << " acs " << type;
        }
      }
    }
  }
};

HWY_TARGET_INSTANTIATE_TEST_SUITE_P_T(
    AcStrategyRoundtrip,
    ::testing::Range(0, int(AcStrategy::Type::kNumValidStrategies)));

TEST_P(AcStrategyRoundtrip, Test) { Run(); }

// Test that DC(2x2) -> DCT coefficients -> IDCT -> downsampled IDCT is a noop.
class AcStrategyRoundtripDownsample
    : public ::hwy::TestWithParamTargetAndT<int> {
 protected:
  void Run() {
    const AcStrategy::Type type = static_cast<AcStrategy::Type>(GetParam());
    const AcStrategy acs = AcStrategy::FromRawStrategy(type);

    auto mem = hwy::AllocateAligned<float>(4 * AcStrategy::kMaxCoeffArea);
    float* scratch_space = mem.get();
    float* coeffs = scratch_space + AcStrategy::kMaxCoeffArea;
    std::fill_n(coeffs, AcStrategy::kMaxCoeffArea, 0.0f);
    float* idct = coeffs + AcStrategy::kMaxCoeffArea;
    Rng rng(type * 65537 + 13);

    for (size_t y = 0; y < acs.covered_blocks_y(); y++) {
      for (size_t x = 0; x < acs.covered_blocks_x(); x++) {
        if (x > 4 || y > 4) {
          if (rng.Bernoulli(0.9f)) continue;
        }
        float* dc = idct + AcStrategy::kMaxCoeffArea;
        std::fill_n(dc, AcStrategy::kMaxCoeffArea, 0);
        dc[y * acs.covered_blocks_x() * 8 + x] = 0.2f;
        LowestFrequenciesFromDC(type, dc, acs.covered_blocks_x() * 8, coeffs,
                                scratch_space);
        TransformToPixels(type, coeffs, idct, acs.covered_blocks_x() * 8,
                          scratch_space);
        std::fill_n(coeffs, AcStrategy::kMaxCoeffArea, 0.0f);
        std::fill_n(dc, AcStrategy::kMaxCoeffArea, 0);
        dc[y * acs.covered_blocks_x() * 8 + x] = 0.2f;
        // Downsample
        for (size_t dy = 0; dy < acs.covered_blocks_y(); dy++) {
          for (size_t dx = 0; dx < acs.covered_blocks_x(); dx++) {
            float sum = 0;
            for (size_t iy = 0; iy < 8; iy++) {
              for (size_t ix = 0; ix < 8; ix++) {
                sum += idct[(dy * 8 + iy) * 8 * acs.covered_blocks_x() +
                            dx * 8 + ix];
              }
            }
            sum /= 64.0f;
            ASSERT_NEAR(sum, dc[dy * 8 * acs.covered_blocks_x() + dx], 1e-6)
                << "acs " << type;
          }
        }
      }
    }
  }
};

HWY_TARGET_INSTANTIATE_TEST_SUITE_P_T(
    AcStrategyRoundtripDownsample,
    ::testing::Range(0, int(AcStrategy::Type::kNumValidStrategies)));

TEST_P(AcStrategyRoundtripDownsample, Test) { Run(); }

// Test that IDCT(block with zeros in the non-topleft corner) -> downsampled
// IDCT is the same as IDCT -> DC(2x2) of the same block.
class AcStrategyDownsample : public ::hwy::TestWithParamTargetAndT<int> {
 protected:
  void Run() {
    const AcStrategy::Type type = static_cast<AcStrategy::Type>(GetParam());
    const AcStrategy acs = AcStrategy::FromRawStrategy(type);
    size_t cx = acs.covered_blocks_y();
    size_t cy = acs.covered_blocks_x();
    CoefficientLayout(&cy, &cx);

    auto mem = hwy::AllocateAligned<float>(4 * AcStrategy::kMaxCoeffArea);
    float* scratch_space = mem.get();
    float* idct = scratch_space + AcStrategy::kMaxCoeffArea;
    float* idct_acs_downsampled = idct + AcStrategy::kMaxCoeffArea;
    Rng rng(type * 65537 + 13);

    for (size_t y = 0; y < cy; y++) {
      for (size_t x = 0; x < cx; x++) {
        if (x > 4 || y > 4) {
          if (rng.Bernoulli(0.9f)) continue;
        }
        float* coeffs = idct + AcStrategy::kMaxCoeffArea;
        std::fill_n(coeffs, AcStrategy::kMaxCoeffArea, 0);
        coeffs[y * cx * 8 + x] = 0.2f;
        TransformToPixels(type, coeffs, idct, acs.covered_blocks_x() * 8,
                          scratch_space);
        std::fill_n(coeffs, AcStrategy::kMaxCoeffArea, 0);
        coeffs[y * cx * 8 + x] = 0.2f;
        DCFromLowestFrequencies(type, coeffs, idct_acs_downsampled,
                                acs.covered_blocks_x() * 8);
        // Downsample
        for (size_t dy = 0; dy < acs.covered_blocks_y(); dy++) {
          for (size_t dx = 0; dx < acs.covered_blocks_x(); dx++) {
            float sum = 0;
            for (size_t iy = 0; iy < 8; iy++) {
              for (size_t ix = 0; ix < 8; ix++) {
                sum += idct[(dy * 8 + iy) * 8 * acs.covered_blocks_x() +
                            dx * 8 + ix];
              }
            }
            sum /= 64;
            ASSERT_NEAR(
                sum, idct_acs_downsampled[dy * 8 * acs.covered_blocks_x() + dx],
                1e-6)
                << " acs " << type;
          }
        }
      }
    }
  }
};

HWY_TARGET_INSTANTIATE_TEST_SUITE_P_T(
    AcStrategyDownsample,
    ::testing::Range(0, int(AcStrategy::Type::kNumValidStrategies)));

TEST_P(AcStrategyDownsample, Test) { Run(); }

class AcStrategyTargetTest : public ::hwy::TestWithParamTarget {};
HWY_TARGET_INSTANTIATE_TEST_SUITE_P(AcStrategyTargetTest);

TEST_P(AcStrategyTargetTest, RoundtripAFVDCT) {
  HWY_ALIGN_MAX float idct[16];
  for (size_t i = 0; i < 16; i++) {
    HWY_ALIGN_MAX float pixels[16] = {};
    pixels[i] = 1;
    HWY_ALIGN_MAX float coeffs[16] = {};

    AFVDCT4x4(pixels, coeffs);
    AFVIDCT4x4(coeffs, idct);
    for (size_t j = 0; j < 16; j++) {
      EXPECT_NEAR(idct[j], pixels[j], 1e-6);
    }
  }
}

TEST_P(AcStrategyTargetTest, BenchmarkAFV) {
  const AcStrategy::Type type = AcStrategy::Type::AFV0;
  HWY_ALIGN_MAX float pixels[64] = {1};
  HWY_ALIGN_MAX float coeffs[64] = {};
  HWY_ALIGN_MAX float scratch_space[64] = {};
  for (size_t i = 0; i < 1 << 14; i++) {
    TransformToPixels(type, coeffs, pixels, 8, scratch_space);
    TransformFromPixels(type, pixels, 8, coeffs, scratch_space);
  }
  EXPECT_NEAR(pixels[0], 0.0, 1E-6);
}

TEST_P(AcStrategyTargetTest, BenchmarkAFVDCT) {
  HWY_ALIGN_MAX float pixels[64] = {1};
  HWY_ALIGN_MAX float coeffs[64] = {};
  for (size_t i = 0; i < 1 << 14; i++) {
    AFVDCT4x4(pixels, coeffs);
    AFVIDCT4x4(coeffs, pixels);
  }
  EXPECT_NEAR(pixels[0], 1.0, 1E-6);
}

}  // namespace
}  // namespace jxl
