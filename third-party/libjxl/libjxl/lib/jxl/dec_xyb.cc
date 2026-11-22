// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/jxl/dec_xyb.h"

#include <string.h>

#undef HWY_TARGET_INCLUDE
#define HWY_TARGET_INCLUDE "lib/jxl/dec_xyb.cc"
#include <hwy/foreach_target.h>
#include <hwy/highway.h>

#include "lib/jxl/base/compiler_specific.h"
#include "lib/jxl/base/status.h"
#include "lib/jxl/dec_group_border.h"
#include "lib/jxl/dec_xyb-inl.h"
#include "lib/jxl/fields.h"
#include "lib/jxl/image.h"
#include "lib/jxl/matrix_ops.h"
#include "lib/jxl/opsin_params.h"
#include "lib/jxl/quantizer.h"
#include "lib/jxl/sanitizers.h"
HWY_BEFORE_NAMESPACE();
namespace jxl {
namespace HWY_NAMESPACE {

// These templates are not found via ADL.
using hwy::HWY_NAMESPACE::MulAdd;

void OpsinToLinearInplace(Image3F* JXL_RESTRICT inout, ThreadPool* pool,
                          const OpsinParams& opsin_params) {
  JXL_CHECK_IMAGE_INITIALIZED(*inout, Rect(*inout));

  const size_t xsize = inout->xsize();  // not padded
  JXL_CHECK(RunOnPool(
      pool, 0, inout->ysize(), ThreadPool::NoInit,
      [&](const uint32_t task, size_t /* thread */) {
        const size_t y = task;

        // Faster than adding via ByteOffset at end of loop.
        float* JXL_RESTRICT row0 = inout->PlaneRow(0, y);
        float* JXL_RESTRICT row1 = inout->PlaneRow(1, y);
        float* JXL_RESTRICT row2 = inout->PlaneRow(2, y);

        const HWY_FULL(float) d;

        for (size_t x = 0; x < xsize; x += Lanes(d)) {
          const auto in_opsin_x = Load(d, row0 + x);
          const auto in_opsin_y = Load(d, row1 + x);
          const auto in_opsin_b = Load(d, row2 + x);
          auto linear_r = Undefined(d);
          auto linear_g = Undefined(d);
          auto linear_b = Undefined(d);
          XybToRgb(d, in_opsin_x, in_opsin_y, in_opsin_b, opsin_params,
                   &linear_r, &linear_g, &linear_b);

          Store(linear_r, d, row0 + x);
          Store(linear_g, d, row1 + x);
          Store(linear_b, d, row2 + x);
        }
      },
      "OpsinToLinear"));
}

// Same, but not in-place.
void OpsinToLinear(const Image3F& opsin, const Rect& rect, ThreadPool* pool,
                   Image3F* JXL_RESTRICT linear,
                   const OpsinParams& opsin_params) {
  JXL_ASSERT(SameSize(rect, *linear));
  JXL_CHECK_IMAGE_INITIALIZED(opsin, rect);

  JXL_CHECK(RunOnPool(
      pool, 0, static_cast<int>(rect.ysize()), ThreadPool::NoInit,
      [&](const uint32_t task, size_t /*thread*/) {
        const size_t y = static_cast<size_t>(task);

        // Faster than adding via ByteOffset at end of loop.
        const float* JXL_RESTRICT row_opsin_0 = rect.ConstPlaneRow(opsin, 0, y);
        const float* JXL_RESTRICT row_opsin_1 = rect.ConstPlaneRow(opsin, 1, y);
        const float* JXL_RESTRICT row_opsin_2 = rect.ConstPlaneRow(opsin, 2, y);
        float* JXL_RESTRICT row_linear_0 = linear->PlaneRow(0, y);
        float* JXL_RESTRICT row_linear_1 = linear->PlaneRow(1, y);
        float* JXL_RESTRICT row_linear_2 = linear->PlaneRow(2, y);

        const HWY_FULL(float) d;

        for (size_t x = 0; x < rect.xsize(); x += Lanes(d)) {
          const auto in_opsin_x = Load(d, row_opsin_0 + x);
          const auto in_opsin_y = Load(d, row_opsin_1 + x);
          const auto in_opsin_b = Load(d, row_opsin_2 + x);
          auto linear_r = Undefined(d);
          auto linear_g = Undefined(d);
          auto linear_b = Undefined(d);
          XybToRgb(d, in_opsin_x, in_opsin_y, in_opsin_b, opsin_params,
                   &linear_r, &linear_g, &linear_b);

          Store(linear_r, d, row_linear_0 + x);
          Store(linear_g, d, row_linear_1 + x);
          Store(linear_b, d, row_linear_2 + x);
        }
      },
      "OpsinToLinear(Rect)"));
  JXL_CHECK_IMAGE_INITIALIZED(*linear, rect);
}

// Transform YCbCr to RGB.
// Could be performed in-place (i.e. Y, Cb and Cr could alias R, B and B).
void YcbcrToRgb(const Image3F& ycbcr, Image3F* rgb, const Rect& rect) {
  JXL_CHECK_IMAGE_INITIALIZED(ycbcr, rect);
  const HWY_CAPPED(float, kBlockDim) df;
  const size_t S = Lanes(df);  // Step.

  const size_t xsize = rect.xsize();
  const size_t ysize = rect.ysize();
  if ((xsize == 0) || (ysize == 0)) return;

  // Full-range BT.601 as defined by JFIF Clause 7:
  // https://www.itu.int/rec/T-REC-T.871-201105-I/en
  const auto c128 = Set(df, 128.0f / 255);
  const auto crcr = Set(df, 1.402f);
  const auto cgcb = Set(df, -0.114f * 1.772f / 0.587f);
  const auto cgcr = Set(df, -0.299f * 1.402f / 0.587f);
  const auto cbcb = Set(df, 1.772f);

  for (size_t y = 0; y < ysize; y++) {
    const float* y_row = rect.ConstPlaneRow(ycbcr, 1, y);
    const float* cb_row = rect.ConstPlaneRow(ycbcr, 0, y);
    const float* cr_row = rect.ConstPlaneRow(ycbcr, 2, y);
    float* r_row = rect.PlaneRow(rgb, 0, y);
    float* g_row = rect.PlaneRow(rgb, 1, y);
    float* b_row = rect.PlaneRow(rgb, 2, y);
    for (size_t x = 0; x < xsize; x += S) {
      const auto y_vec = Add(Load(df, y_row + x), c128);
      const auto cb_vec = Load(df, cb_row + x);
      const auto cr_vec = Load(df, cr_row + x);
      const auto r_vec = MulAdd(crcr, cr_vec, y_vec);
      const auto g_vec = MulAdd(cgcr, cr_vec, MulAdd(cgcb, cb_vec, y_vec));
      const auto b_vec = MulAdd(cbcb, cb_vec, y_vec);
      Store(r_vec, df, r_row + x);
      Store(g_vec, df, g_row + x);
      Store(b_vec, df, b_row + x);
    }
  }
  JXL_CHECK_IMAGE_INITIALIZED(*rgb, rect);
}

// NOLINTNEXTLINE(google-readability-namespace-comments)
}  // namespace HWY_NAMESPACE
}  // namespace jxl
HWY_AFTER_NAMESPACE();

#if HWY_ONCE
namespace jxl {

HWY_EXPORT(OpsinToLinearInplace);
void OpsinToLinearInplace(Image3F* JXL_RESTRICT inout, ThreadPool* pool,
                          const OpsinParams& opsin_params) {
  return HWY_DYNAMIC_DISPATCH(OpsinToLinearInplace)(inout, pool, opsin_params);
}

HWY_EXPORT(OpsinToLinear);
void OpsinToLinear(const Image3F& opsin, const Rect& rect, ThreadPool* pool,
                   Image3F* JXL_RESTRICT linear,
                   const OpsinParams& opsin_params) {
  return HWY_DYNAMIC_DISPATCH(OpsinToLinear)(opsin, rect, pool, linear,
                                             opsin_params);
}

HWY_EXPORT(YcbcrToRgb);
void YcbcrToRgb(const Image3F& ycbcr, Image3F* rgb, const Rect& rect) {
  return HWY_DYNAMIC_DISPATCH(YcbcrToRgb)(ycbcr, rgb, rect);
}

HWY_EXPORT(HasFastXYBTosRGB8);
bool HasFastXYBTosRGB8() { return HWY_DYNAMIC_DISPATCH(HasFastXYBTosRGB8)(); }

HWY_EXPORT(FastXYBTosRGB8);
void FastXYBTosRGB8(const float* input[4], uint8_t* output, bool is_rgba,
                    size_t xsize) {
  return HWY_DYNAMIC_DISPATCH(FastXYBTosRGB8)(input, output, is_rgba, xsize);
}

void OpsinParams::Init(float intensity_target) {
  InitSIMDInverseMatrix(GetOpsinAbsorbanceInverseMatrix(), inverse_opsin_matrix,
                        intensity_target);
  memcpy(opsin_biases, kNegOpsinAbsorbanceBiasRGB,
         sizeof(kNegOpsinAbsorbanceBiasRGB));
  memcpy(quant_biases, kDefaultQuantBias, sizeof(kDefaultQuantBias));
  for (size_t c = 0; c < 4; c++) {
    opsin_biases_cbrt[c] = cbrtf(opsin_biases[c]);
  }
}

bool CanOutputToColorEncoding(const ColorEncoding& c_desired) {
  if (!c_desired.HaveFields()) {
    return false;
  }
  // TODO(veluca): keep in sync with dec_reconstruct.cc
  if (!c_desired.tf.IsPQ() && !c_desired.tf.IsSRGB() &&
      !c_desired.tf.IsGamma() && !c_desired.tf.IsLinear() &&
      !c_desired.tf.IsHLG() && !c_desired.tf.IsDCI() && !c_desired.tf.Is709()) {
    return false;
  }
  if (c_desired.IsGray() && c_desired.white_point != WhitePoint::kD65) {
    // TODO(veluca): figure out what should happen here.
    return false;
  }
  return true;
}

Status OutputEncodingInfo::SetFromMetadata(const CodecMetadata& metadata) {
  orig_color_encoding = metadata.m.color_encoding;
  orig_intensity_target = metadata.m.IntensityTarget();
  desired_intensity_target = orig_intensity_target;
  const auto& im = metadata.transform_data.opsin_inverse_matrix;
  memcpy(orig_inverse_matrix, im.inverse_matrix, sizeof(orig_inverse_matrix));
  default_transform = im.all_default;
  xyb_encoded = metadata.m.xyb_encoded;
  std::copy(std::begin(im.opsin_biases), std::end(im.opsin_biases),
            opsin_params.opsin_biases);
  for (int i = 0; i < 3; ++i) {
    opsin_params.opsin_biases_cbrt[i] = cbrtf(opsin_params.opsin_biases[i]);
  }
  opsin_params.opsin_biases_cbrt[3] = opsin_params.opsin_biases[3] = 1;
  std::copy(std::begin(im.quant_biases), std::end(im.quant_biases),
            opsin_params.quant_biases);
  bool orig_ok = CanOutputToColorEncoding(orig_color_encoding);
  bool orig_grey = orig_color_encoding.IsGray();
  return SetColorEncoding(!xyb_encoded || orig_ok
                              ? orig_color_encoding
                              : ColorEncoding::LinearSRGB(orig_grey));
}

Status OutputEncodingInfo::MaybeSetColorEncoding(
    const ColorEncoding& c_desired) {
  if (c_desired.GetColorSpace() == ColorSpace::kXYB &&
      ((color_encoding.GetColorSpace() == ColorSpace::kRGB &&
        color_encoding.primaries != Primaries::kSRGB) ||
       color_encoding.tf.IsPQ())) {
    return false;
  }
  if (!xyb_encoded && !CanOutputToColorEncoding(c_desired)) {
    return false;
  }
  return SetColorEncoding(c_desired);
}

Status OutputEncodingInfo::SetColorEncoding(const ColorEncoding& c_desired) {
  color_encoding = c_desired;
  color_encoding_is_original = orig_color_encoding.SameColorEncoding(c_desired);

  // Compute the opsin inverse matrix and luminances based on primaries and
  // white point.
  float inverse_matrix[9];
  bool inverse_matrix_is_default = default_transform;
  memcpy(inverse_matrix, orig_inverse_matrix, sizeof(inverse_matrix));
  constexpr float kSRGBLuminances[3] = {0.2126, 0.7152, 0.0722};
  memcpy(luminances, kSRGBLuminances, sizeof(luminances));
  if ((c_desired.primaries != Primaries::kSRGB ||
       c_desired.white_point != WhitePoint::kD65) &&
      !c_desired.IsGray()) {
    float srgb_to_xyzd50[9];
    const auto& srgb = ColorEncoding::SRGB(/*is_gray=*/false);
    JXL_CHECK(PrimariesToXYZD50(
        srgb.GetPrimaries().r.x, srgb.GetPrimaries().r.y,
        srgb.GetPrimaries().g.x, srgb.GetPrimaries().g.y,
        srgb.GetPrimaries().b.x, srgb.GetPrimaries().b.y,
        srgb.GetWhitePoint().x, srgb.GetWhitePoint().y, srgb_to_xyzd50));
    float original_to_xyz[3][3];
    JXL_RETURN_IF_ERROR(PrimariesToXYZ(
        c_desired.GetPrimaries().r.x, c_desired.GetPrimaries().r.y,
        c_desired.GetPrimaries().g.x, c_desired.GetPrimaries().g.y,
        c_desired.GetPrimaries().b.x, c_desired.GetPrimaries().b.y,
        c_desired.GetWhitePoint().x, c_desired.GetWhitePoint().y,
        &original_to_xyz[0][0]));
    memcpy(luminances, original_to_xyz[1], sizeof luminances);
    if (xyb_encoded) {
      float adapt_to_d50[9];
      JXL_RETURN_IF_ERROR(AdaptToXYZD50(c_desired.GetWhitePoint().x,
                                        c_desired.GetWhitePoint().y,
                                        adapt_to_d50));
      float xyzd50_to_original[9];
      Mul3x3Matrix(adapt_to_d50, &original_to_xyz[0][0], xyzd50_to_original);
      JXL_RETURN_IF_ERROR(Inv3x3Matrix(xyzd50_to_original));
      float srgb_to_original[9];
      Mul3x3Matrix(xyzd50_to_original, srgb_to_xyzd50, srgb_to_original);
      Mul3x3Matrix(srgb_to_original, orig_inverse_matrix, inverse_matrix);
      inverse_matrix_is_default = false;
    }
  }

  if (c_desired.IsGray()) {
    float tmp_inv_matrix[9];
    memcpy(tmp_inv_matrix, inverse_matrix, sizeof(inverse_matrix));
    float srgb_to_luma[9];
    memcpy(&srgb_to_luma[0], luminances, sizeof(luminances));
    memcpy(&srgb_to_luma[3], luminances, sizeof(luminances));
    memcpy(&srgb_to_luma[6], luminances, sizeof(luminances));
    Mul3x3Matrix(srgb_to_luma, tmp_inv_matrix, inverse_matrix);
  }

  // The internal XYB color space uses absolute luminance, so we scale back the
  // opsin inverse matrix to relative luminance where 1.0 corresponds to the
  // original intensity target, or to absolute luminance for PQ, where 1.0
  // corresponds to 10000 nits.
  if (xyb_encoded) {
    float intensity_target =
        (c_desired.tf.IsPQ() ? 10000 : orig_intensity_target);
    InitSIMDInverseMatrix(inverse_matrix, opsin_params.inverse_opsin_matrix,
                          intensity_target);
    all_default_opsin = (std::abs(intensity_target - 255.0) <= 0.1f &&
                         inverse_matrix_is_default);
  }

  // Set the inverse gamma based on color space transfer function.
  inverse_gamma = (c_desired.tf.IsGamma() ? c_desired.tf.GetGamma()
                   : c_desired.tf.IsDCI() ? 1.0f / 2.6f
                                          : 1.0);
  return true;
}

}  // namespace jxl
#endif  // HWY_ONCE
