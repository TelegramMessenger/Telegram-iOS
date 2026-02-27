// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#if defined(LIB_JPEGLI_ENTROPY_CODING_INL_H_) == defined(HWY_TARGET_TOGGLE)
#ifdef LIB_JPEGLI_ENTROPY_CODING_INL_H_
#undef LIB_JPEGLI_ENTROPY_CODING_INL_H_
#else
#define LIB_JPEGLI_ENTROPY_CODING_INL_H_
#endif

#include "lib/jxl/base/compiler_specific.h"

HWY_BEFORE_NAMESPACE();
namespace jpegli {
namespace HWY_NAMESPACE {
namespace {

// These templates are not found via ADL.
using hwy::HWY_NAMESPACE::Abs;
using hwy::HWY_NAMESPACE::Add;
using hwy::HWY_NAMESPACE::And;
using hwy::HWY_NAMESPACE::AndNot;
using hwy::HWY_NAMESPACE::Compress;
using hwy::HWY_NAMESPACE::CountTrue;
using hwy::HWY_NAMESPACE::Eq;
using hwy::HWY_NAMESPACE::GetLane;
using hwy::HWY_NAMESPACE::MaskFromVec;
using hwy::HWY_NAMESPACE::Max;
using hwy::HWY_NAMESPACE::Not;
using hwy::HWY_NAMESPACE::Or;
using hwy::HWY_NAMESPACE::ShiftRight;
using hwy::HWY_NAMESPACE::Shl;
using hwy::HWY_NAMESPACE::Sub;

using DI = HWY_FULL(int32_t);
constexpr DI di;

template <typename DI, class V>
JXL_INLINE V NumBits(DI di, const V x) {
  // TODO(szabadka) Add faster implementations for some specific architectures.
  const auto b1 = And(x, Set(di, 1));
  const auto b2 = And(x, Set(di, 2));
  const auto b3 = Sub((And(x, Set(di, 4))), Set(di, 1));
  const auto b4 = Sub((And(x, Set(di, 8))), Set(di, 4));
  const auto b5 = Sub((And(x, Set(di, 16))), Set(di, 11));
  const auto b6 = Sub((And(x, Set(di, 32))), Set(di, 26));
  const auto b7 = Sub((And(x, Set(di, 64))), Set(di, 57));
  const auto b8 = Sub((And(x, Set(di, 128))), Set(di, 120));
  const auto b9 = Sub((And(x, Set(di, 256))), Set(di, 247));
  const auto b10 = Sub((And(x, Set(di, 512))), Set(di, 502));
  const auto b11 = Sub((And(x, Set(di, 1024))), Set(di, 1013));
  const auto b12 = Sub((And(x, Set(di, 2048))), Set(di, 2036));
  return Max(Max(Max(Max(b1, b2), Max(b3, b4)), Max(Max(b5, b6), Max(b7, b8))),
             Max(Max(b9, b10), Max(b11, b12)));
}

// Coefficient indexes pre-multiplied by 16 for the symbol calculation.
HWY_ALIGN constexpr int32_t kIndexes[64] = {
    0,   16,  32,  48,  64,  80,  96,  112, 128, 144, 160, 176,  192,
    208, 224, 240, 256, 272, 288, 304, 320, 336, 352, 368, 384,  400,
    416, 432, 448, 464, 480, 496, 512, 528, 544, 560, 576, 592,  608,
    624, 640, 656, 672, 688, 704, 720, 736, 752, 768, 784, 800,  816,
    832, 848, 864, 880, 896, 912, 928, 944, 960, 976, 992, 1008,
};

JXL_INLINE int CompactBlock(int32_t* JXL_RESTRICT block,
                            int32_t* JXL_RESTRICT nonzero_idx) {
  const auto zero = Zero(di);
  HWY_ALIGN constexpr int32_t dc_mask_lanes[HWY_LANES(DI)] = {-1};
  const auto dc_mask = MaskFromVec(Load(di, dc_mask_lanes));
  int num_nonzeros = 0;
  int k = 0;
  {
    const auto coef = Load(di, block);
    const auto idx = Load(di, kIndexes);
    const auto nonzero_mask = Or(dc_mask, Not(Eq(coef, zero)));
    const auto nzero_coef = Compress(coef, nonzero_mask);
    const auto nzero_idx = Compress(idx, nonzero_mask);
    StoreU(nzero_coef, di, &block[num_nonzeros]);
    StoreU(nzero_idx, di, &nonzero_idx[num_nonzeros]);
    num_nonzeros += CountTrue(di, nonzero_mask);
    k += Lanes(di);
  }
  for (; k < DCTSIZE2; k += Lanes(di)) {
    const auto coef = Load(di, &block[k]);
    const auto idx = Load(di, &kIndexes[k]);
    const auto nonzero_mask = Not(Eq(coef, zero));
    const auto nzero_coef = Compress(coef, nonzero_mask);
    const auto nzero_idx = Compress(idx, nonzero_mask);
    StoreU(nzero_coef, di, &block[num_nonzeros]);
    StoreU(nzero_idx, di, &nonzero_idx[num_nonzeros]);
    num_nonzeros += CountTrue(di, nonzero_mask);
  }
  return num_nonzeros;
}

JXL_INLINE void ComputeSymbols(const int num_nonzeros,
                               int32_t* JXL_RESTRICT nonzero_idx,
                               int32_t* JXL_RESTRICT block,
                               int32_t* JXL_RESTRICT symbols) {
  nonzero_idx[-1] = -16;
  const auto one = Set(di, 1);
  const auto offset = Set(di, 16);
  for (int i = 0; i < num_nonzeros; i += Lanes(di)) {
    const auto idx = Load(di, &nonzero_idx[i]);
    const auto prev_idx = LoadU(di, &nonzero_idx[i - 1]);
    const auto coeff = Load(di, &block[i]);
    const auto nbits = NumBits(di, Abs(coeff));
    const auto mask = ShiftRight<8 * sizeof(int32_t) - 1>(coeff);
    const auto bits = And(Add(coeff, mask), Sub(Shl(one, nbits), one));
    const auto symbol = Sub(Add(nbits, idx), Add(prev_idx, offset));
    Store(symbol, di, symbols + i);
    Store(bits, di, block + i);
  }
}

template <typename T>
int NumNonZero8x8ExceptDC(const T* block) {
  const HWY_CAPPED(T, 8) di;

  const auto zero = Zero(di);
  // Add FFFF for every zero coefficient, negate to get #zeros.
  auto neg_sum_zero = zero;
  {
    // First row has DC, so mask
    const size_t y = 0;
    HWY_ALIGN const T dc_mask_lanes[8] = {-1};

    for (size_t x = 0; x < 8; x += Lanes(di)) {
      const auto dc_mask = Load(di, dc_mask_lanes + x);

      // DC counts as zero so we don't include it in nzeros.
      const auto coef = AndNot(dc_mask, Load(di, &block[y * 8 + x]));

      neg_sum_zero = Add(neg_sum_zero, VecFromMask(di, Eq(coef, zero)));
    }
  }
  // Remaining rows: no mask
  for (size_t y = 1; y < 8; y++) {
    for (size_t x = 0; x < 8; x += Lanes(di)) {
      const auto coef = Load(di, &block[y * 8 + x]);
      neg_sum_zero = Add(neg_sum_zero, VecFromMask(di, Eq(coef, zero)));
    }
  }

  // We want 64 - sum_zero, add because neg_sum_zero is already negated.
  return kDCTBlockSize + GetLane(SumOfLanes(di, neg_sum_zero));
}

template <typename T, bool zig_zag_order>
void ComputeTokensForBlock(const T* block, int last_dc, int dc_ctx, int ac_ctx,
                           Token** tokens_ptr) {
  Token* next_token = *tokens_ptr;
  coeff_t temp2;
  coeff_t temp;
  temp = block[0] - last_dc;
  if (temp == 0) {
    *next_token++ = Token(dc_ctx, 0, 0);
  } else {
    temp2 = temp;
    if (temp < 0) {
      temp = -temp;
      temp2--;
    }
    int dc_nbits = jxl::FloorLog2Nonzero<uint32_t>(temp) + 1;
    int dc_mask = (1 << dc_nbits) - 1;
    *next_token++ = Token(dc_ctx, dc_nbits, temp2 & dc_mask);
  }
  int num_nonzeros = NumNonZero8x8ExceptDC(block);
  for (int k = 1; k < 64; ++k) {
    if (num_nonzeros == 0) {
      *next_token++ = Token(ac_ctx, 0, 0);
      break;
    }
    int r = 0;
    if (zig_zag_order) {
      while ((temp = block[k]) == 0) {
        r++;
        k++;
      }
    } else {
      while ((temp = block[kJPEGNaturalOrder[k]]) == 0) {
        r++;
        k++;
      }
    }
    --num_nonzeros;
    if (temp < 0) {
      temp = -temp;
      temp2 = ~temp;
    } else {
      temp2 = temp;
    }
    while (r > 15) {
      *next_token++ = Token(ac_ctx, 0xf0, 0);
      r -= 16;
    }
    int ac_nbits = jxl::FloorLog2Nonzero<uint32_t>(temp) + 1;
    int ac_mask = (1 << ac_nbits) - 1;
    int symbol = (r << 4u) + ac_nbits;
    *next_token++ = Token(ac_ctx, symbol, temp2 & ac_mask);
  }
  *tokens_ptr = next_token;
}

// NOLINTNEXTLINE(google-readability-namespace-comments)
}  // namespace
}  // namespace HWY_NAMESPACE
}  // namespace jpegli
HWY_AFTER_NAMESPACE();
#endif  // LIB_JPEGLI_ENTROPY_CODING_INL_H_
