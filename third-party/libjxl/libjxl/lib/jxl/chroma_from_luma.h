// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef LIB_JXL_CHROMA_FROM_LUMA_H_
#define LIB_JXL_CHROMA_FROM_LUMA_H_

// Chroma-from-luma, computed using heuristics to determine the best linear
// model for the X and B channels from the Y channel.

#include <stddef.h>
#include <stdint.h>

#include <vector>

#include "lib/jxl/base/compiler_specific.h"
#include "lib/jxl/base/data_parallel.h"
#include "lib/jxl/base/status.h"
#include "lib/jxl/common.h"
#include "lib/jxl/dec_bit_reader.h"
#include "lib/jxl/entropy_coder.h"
#include "lib/jxl/field_encodings.h"
#include "lib/jxl/fields.h"
#include "lib/jxl/image.h"
#include "lib/jxl/opsin_params.h"
#include "lib/jxl/quant_weights.h"

namespace jxl {

// Tile is the rectangular grid of blocks that share color correlation
// parameters ("factor_x/b" such that residual_b = blue - Y * factor_b).
static constexpr size_t kColorTileDim = 64;

static_assert(kColorTileDim % kBlockDim == 0,
              "Color tile dim should be divisible by block dim");
static constexpr size_t kColorTileDimInBlocks = kColorTileDim / kBlockDim;

static_assert(kGroupDimInBlocks % kColorTileDimInBlocks == 0,
              "Group dim should be divisible by color tile dim");

static constexpr uint8_t kDefaultColorFactor = 84;

// JPEG DCT coefficients are at most 1024. CfL constants are at most 127, and
// the ratio of two entries in a JPEG quantization table is at most 255. Thus,
// since the CfL denominator is 84, this leaves 12 bits of mantissa to be used.
// For extra caution, we use 11.
static constexpr uint8_t kCFLFixedPointPrecision = 11;

static constexpr U32Enc kColorFactorDist(Val(kDefaultColorFactor), Val(256),
                                         BitsOffset(8, 2), BitsOffset(16, 258));

struct ColorCorrelationMap {
  ColorCorrelationMap() = default;
  // xsize/ysize are in pixels
  // set XYB=false to do something close to no-op cmap (needed for now since
  // cmap is mandatory)
  ColorCorrelationMap(size_t xsize, size_t ysize, bool XYB = true);

  float YtoXRatio(int32_t x_factor) const {
    return base_correlation_x_ + x_factor * color_scale_;
  }

  float YtoBRatio(int32_t b_factor) const {
    return base_correlation_b_ + b_factor * color_scale_;
  }

  Status DecodeDC(BitReader* br) {
    if (br->ReadFixedBits<1>() == 1) {
      // All default.
      return true;
    }
    SetColorFactor(U32Coder::Read(kColorFactorDist, br));
    JXL_RETURN_IF_ERROR(F16Coder::Read(br, &base_correlation_x_));
    if (std::abs(base_correlation_x_) > 4.0f) {
      return JXL_FAILURE("Base X correlation is out of range");
    }
    JXL_RETURN_IF_ERROR(F16Coder::Read(br, &base_correlation_b_));
    if (std::abs(base_correlation_b_) > 4.0f) {
      return JXL_FAILURE("Base B correlation is out of range");
    }
    ytox_dc_ = static_cast<int>(br->ReadFixedBits<kBitsPerByte>()) +
               std::numeric_limits<int8_t>::min();
    ytob_dc_ = static_cast<int>(br->ReadFixedBits<kBitsPerByte>()) +
               std::numeric_limits<int8_t>::min();
    RecomputeDCFactors();
    return true;
  }

  // We consider a CfL map to be JPEG-reconstruction-compatible if base
  // correlation is 0, no DC correlation is used, and we use the default color
  // factor.
  bool IsJPEGCompatible() const {
    return base_correlation_x_ == 0 && base_correlation_b_ == 0 &&
           ytob_dc_ == 0 && ytox_dc_ == 0 &&
           color_factor_ == kDefaultColorFactor;
  }

  int32_t RatioJPEG(int32_t factor) const {
    return factor * (1 << kCFLFixedPointPrecision) / kDefaultColorFactor;
  }

  void SetColorFactor(uint32_t factor) {
    color_factor_ = factor;
    color_scale_ = 1.0f / color_factor_;
    RecomputeDCFactors();
  }

  void SetYToBDC(int32_t ytob_dc) {
    ytob_dc_ = ytob_dc;
    RecomputeDCFactors();
  }
  void SetYToXDC(int32_t ytox_dc) {
    ytox_dc_ = ytox_dc;
    RecomputeDCFactors();
  }

  int32_t GetYToXDC() const { return ytox_dc_; }
  int32_t GetYToBDC() const { return ytob_dc_; }
  float GetColorFactor() const { return color_factor_; }
  float GetBaseCorrelationX() const { return base_correlation_x_; }
  float GetBaseCorrelationB() const { return base_correlation_b_; }

  const float* DCFactors() const { return dc_factors_; }

  void RecomputeDCFactors() {
    dc_factors_[0] = YtoXRatio(ytox_dc_);
    dc_factors_[2] = YtoBRatio(ytob_dc_);
  }

  ImageSB ytox_map;
  ImageSB ytob_map;

 private:
  float dc_factors_[4] = {};
  // range of factor: -1.51 to +1.52
  uint32_t color_factor_ = kDefaultColorFactor;
  float color_scale_ = 1.0f / color_factor_;
  float base_correlation_x_ = 0.0f;
  float base_correlation_b_ = kYToBRatio;
  int32_t ytox_dc_ = 0;
  int32_t ytob_dc_ = 0;
};

}  // namespace jxl

#endif  // LIB_JXL_CHROMA_FROM_LUMA_H_
