// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/jxl/enc_image_bundle.h"

#include <jxl/cms_interface.h>

#include <atomic>
#include <limits>
#include <utility>

#include "lib/jxl/alpha.h"
#include "lib/jxl/base/byte_order.h"
#include "lib/jxl/base/padded_bytes.h"
#include "lib/jxl/enc_color_management.h"
#include "lib/jxl/fields.h"
#include "lib/jxl/image_bundle.h"

namespace jxl {

namespace {

// Copies ib:rect, converts, and copies into out.
Status CopyToT(const ImageMetadata* metadata, const ImageBundle* ib,
               const Rect& rect, const ColorEncoding& c_desired,
               const JxlCmsInterface& cms, ThreadPool* pool, Image3F* out) {
  ColorSpaceTransform c_transform(cms);
  // Changing IsGray is probably a bug.
  JXL_CHECK(ib->IsGray() == c_desired.IsGray());
  bool is_gray = ib->IsGray();
  if (out->xsize() < rect.xsize() || out->ysize() < rect.ysize()) {
    *out = Image3F(rect.xsize(), rect.ysize());
  } else {
    out->ShrinkTo(rect.xsize(), rect.ysize());
  }
  std::atomic<bool> ok{true};
  JXL_RETURN_IF_ERROR(RunOnPool(
      pool, 0, rect.ysize(),
      [&](const size_t num_threads) {
        return c_transform.Init(ib->c_current(), c_desired,
                                metadata->IntensityTarget(), rect.xsize(),
                                num_threads);
      },
      [&](const uint32_t y, const size_t thread) {
        float* mutable_src_buf = c_transform.BufSrc(thread);
        const float* src_buf = mutable_src_buf;
        // Interleave input.
        if (is_gray) {
          src_buf = rect.ConstPlaneRow(ib->color(), 0, y);
        } else if (ib->c_current().IsCMYK()) {
          if (!ib->HasBlack()) {
            ok.store(false);
            return;
          }
          const float* JXL_RESTRICT row_in0 =
              rect.ConstPlaneRow(ib->color(), 0, y);
          const float* JXL_RESTRICT row_in1 =
              rect.ConstPlaneRow(ib->color(), 1, y);
          const float* JXL_RESTRICT row_in2 =
              rect.ConstPlaneRow(ib->color(), 2, y);
          const float* JXL_RESTRICT row_in3 = rect.ConstRow(ib->black(), y);
          for (size_t x = 0; x < rect.xsize(); x++) {
            // CMYK convention in JXL: 0 = max ink, 1 = white
            mutable_src_buf[4 * x + 0] = row_in0[x];
            mutable_src_buf[4 * x + 1] = row_in1[x];
            mutable_src_buf[4 * x + 2] = row_in2[x];
            mutable_src_buf[4 * x + 3] = row_in3[x];
          }
        } else {
          const float* JXL_RESTRICT row_in0 =
              rect.ConstPlaneRow(ib->color(), 0, y);
          const float* JXL_RESTRICT row_in1 =
              rect.ConstPlaneRow(ib->color(), 1, y);
          const float* JXL_RESTRICT row_in2 =
              rect.ConstPlaneRow(ib->color(), 2, y);
          for (size_t x = 0; x < rect.xsize(); x++) {
            mutable_src_buf[3 * x + 0] = row_in0[x];
            mutable_src_buf[3 * x + 1] = row_in1[x];
            mutable_src_buf[3 * x + 2] = row_in2[x];
          }
        }
        float* JXL_RESTRICT dst_buf = c_transform.BufDst(thread);
        if (!c_transform.Run(thread, src_buf, dst_buf)) {
          ok.store(false);
          return;
        }
        float* JXL_RESTRICT row_out0 = out->PlaneRow(0, y);
        float* JXL_RESTRICT row_out1 = out->PlaneRow(1, y);
        float* JXL_RESTRICT row_out2 = out->PlaneRow(2, y);
        // De-interleave output and convert type.
        if (is_gray) {
          for (size_t x = 0; x < rect.xsize(); x++) {
            row_out0[x] = dst_buf[x];
            row_out1[x] = dst_buf[x];
            row_out2[x] = dst_buf[x];
          }
        } else {
          for (size_t x = 0; x < rect.xsize(); x++) {
            row_out0[x] = dst_buf[3 * x + 0];
            row_out1[x] = dst_buf[3 * x + 1];
            row_out2[x] = dst_buf[3 * x + 2];
          }
        }
      },
      "Colorspace transform"));
  return ok.load();
}

}  // namespace

Status ImageBundle::TransformTo(const ColorEncoding& c_desired,
                                const JxlCmsInterface& cms, ThreadPool* pool) {
  JXL_RETURN_IF_ERROR(CopyTo(Rect(color_), c_desired, cms, &color_, pool));
  c_current_ = c_desired;
  return true;
}
Status ImageBundle::CopyTo(const Rect& rect, const ColorEncoding& c_desired,
                           const JxlCmsInterface& cms, Image3F* out,
                           ThreadPool* pool) const {
  return CopyToT(metadata_, this, rect, c_desired, cms, pool, out);
}
Status TransformIfNeeded(const ImageBundle& in, const ColorEncoding& c_desired,
                         const JxlCmsInterface& cms, ThreadPool* pool,
                         ImageBundle* store, const ImageBundle** out) {
  if (in.c_current().SameColorEncoding(c_desired) && !in.HasBlack()) {
    *out = &in;
    return true;
  }
  // TODO(janwas): avoid copying via createExternal+copyBackToIO
  // instead of copy+createExternal+copyBackToIO
  Image3F color(in.color().xsize(), in.color().ysize());
  CopyImageTo(in.color(), &color);
  store->SetFromImage(std::move(color), in.c_current());

  // Must at least copy the alpha channel for use by external_image.
  if (in.HasExtraChannels()) {
    std::vector<ImageF> extra_channels;
    for (const ImageF& extra_channel : in.extra_channels()) {
      ImageF ec(extra_channel.xsize(), extra_channel.ysize());
      CopyImageTo(extra_channel, &ec);
      extra_channels.emplace_back(std::move(ec));
    }
    store->SetExtraChannels(std::move(extra_channels));
  }

  if (!store->TransformTo(c_desired, cms, pool)) {
    return false;
  }
  *out = store;
  return true;
}

}  // namespace jxl
