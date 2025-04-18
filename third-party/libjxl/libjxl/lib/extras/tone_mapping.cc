// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/extras/tone_mapping.h"

#undef HWY_TARGET_INCLUDE
#define HWY_TARGET_INCLUDE "lib/extras/tone_mapping.cc"
#include <hwy/foreach_target.h>
#include <hwy/highway.h>

#include "lib/jxl/dec_tone_mapping-inl.h"
#include "lib/jxl/enc_color_management.h"
#include "lib/jxl/image_bundle.h"

HWY_BEFORE_NAMESPACE();
namespace jxl {
namespace HWY_NAMESPACE {

static constexpr float rec2020_luminances[3] = {0.2627f, 0.6780f, 0.0593f};

Status ToneMapFrame(const std::pair<float, float> display_nits,
                    ImageBundle* const ib, ThreadPool* const pool) {
  // Perform tone mapping as described in Report ITU-R BT.2390-8, section 5.4
  // (pp. 23-25).
  // https://www.itu.int/pub/R-REP-BT.2390-8-2020

  HWY_FULL(float) df;
  using V = decltype(Zero(df));

  ColorEncoding linear_rec2020;
  linear_rec2020.SetColorSpace(ColorSpace::kRGB);
  linear_rec2020.primaries = Primaries::k2100;
  linear_rec2020.white_point = WhitePoint::kD65;
  linear_rec2020.tf.SetTransferFunction(TransferFunction::kLinear);
  JXL_RETURN_IF_ERROR(linear_rec2020.CreateICC());
  JXL_RETURN_IF_ERROR(ib->TransformTo(linear_rec2020, GetJxlCms(), pool));

  Rec2408ToneMapper<decltype(df)> tone_mapper(
      {ib->metadata()->tone_mapping.min_nits,
       ib->metadata()->IntensityTarget()},
      display_nits, rec2020_luminances);

  return RunOnPool(
      pool, 0, ib->ysize(), ThreadPool::NoInit,
      [&](const uint32_t y, size_t /* thread */) {
        float* const JXL_RESTRICT row_r = ib->color()->PlaneRow(0, y);
        float* const JXL_RESTRICT row_g = ib->color()->PlaneRow(1, y);
        float* const JXL_RESTRICT row_b = ib->color()->PlaneRow(2, y);
        for (size_t x = 0; x < ib->xsize(); x += Lanes(df)) {
          V red = Load(df, row_r + x);
          V green = Load(df, row_g + x);
          V blue = Load(df, row_b + x);
          tone_mapper.ToneMap(&red, &green, &blue);
          Store(red, df, row_r + x);
          Store(green, df, row_g + x);
          Store(blue, df, row_b + x);
        }
      },
      "ToneMap");
}

Status GamutMapFrame(ImageBundle* const ib, float preserve_saturation,
                     ThreadPool* const pool) {
  HWY_FULL(float) df;
  using V = decltype(Zero(df));

  ColorEncoding linear_rec2020;
  linear_rec2020.SetColorSpace(ColorSpace::kRGB);
  linear_rec2020.primaries = Primaries::k2100;
  linear_rec2020.white_point = WhitePoint::kD65;
  linear_rec2020.tf.SetTransferFunction(TransferFunction::kLinear);
  JXL_RETURN_IF_ERROR(linear_rec2020.CreateICC());
  JXL_RETURN_IF_ERROR(ib->TransformTo(linear_rec2020, GetJxlCms(), pool));

  JXL_RETURN_IF_ERROR(RunOnPool(
      pool, 0, ib->ysize(), ThreadPool::NoInit,
      [&](const uint32_t y, size_t /* thread*/) {
        float* const JXL_RESTRICT row_r = ib->color()->PlaneRow(0, y);
        float* const JXL_RESTRICT row_g = ib->color()->PlaneRow(1, y);
        float* const JXL_RESTRICT row_b = ib->color()->PlaneRow(2, y);
        for (size_t x = 0; x < ib->xsize(); x += Lanes(df)) {
          V red = Load(df, row_r + x);
          V green = Load(df, row_g + x);
          V blue = Load(df, row_b + x);
          GamutMap(&red, &green, &blue, rec2020_luminances,
                   preserve_saturation);
          Store(red, df, row_r + x);
          Store(green, df, row_g + x);
          Store(blue, df, row_b + x);
        }
      },
      "GamutMap"));

  return true;
}

// NOLINTNEXTLINE(google-readability-namespace-comments)
}  // namespace HWY_NAMESPACE
}  // namespace jxl
HWY_AFTER_NAMESPACE();

#if HWY_ONCE
namespace jxl {

namespace {
HWY_EXPORT(ToneMapFrame);
HWY_EXPORT(GamutMapFrame);
}  // namespace

Status ToneMapTo(const std::pair<float, float> display_nits,
                 CodecInOut* const io, ThreadPool* const pool) {
  const auto tone_map_frame = HWY_DYNAMIC_DISPATCH(ToneMapFrame);
  for (ImageBundle& ib : io->frames) {
    JXL_RETURN_IF_ERROR(tone_map_frame(display_nits, &ib, pool));
  }
  io->metadata.m.SetIntensityTarget(display_nits.second);
  return true;
}

Status GamutMap(CodecInOut* const io, float preserve_saturation,
                ThreadPool* const pool) {
  const auto gamut_map_frame = HWY_DYNAMIC_DISPATCH(GamutMapFrame);
  for (ImageBundle& ib : io->frames) {
    JXL_RETURN_IF_ERROR(gamut_map_frame(&ib, preserve_saturation, pool));
  }
  return true;
}

}  // namespace jxl
#endif
