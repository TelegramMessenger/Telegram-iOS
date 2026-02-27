// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/jxl/image_bundle.h"

#include <limits>
#include <utility>

#include "lib/jxl/base/byte_order.h"
#include "lib/jxl/base/padded_bytes.h"
#include "lib/jxl/base/printf_macros.h"
#include "lib/jxl/color_management.h"
#include "lib/jxl/fields.h"

namespace jxl {

void ImageBundle::ShrinkTo(size_t xsize, size_t ysize) {
  if (HasColor()) color_.ShrinkTo(xsize, ysize);
  for (ImageF& ec : extra_channels_) {
    ec.ShrinkTo(xsize, ysize);
  }
}

// Called by all other SetFrom*.
void ImageBundle::SetFromImage(Image3F&& color,
                               const ColorEncoding& c_current) {
  JXL_CHECK(color.xsize() != 0 && color.ysize() != 0);
  JXL_CHECK(metadata_->color_encoding.IsGray() == c_current.IsGray());
  color_ = std::move(color);
  c_current_ = c_current;
  VerifySizes();
}

void ImageBundle::VerifyMetadata() const {
  JXL_CHECK(!c_current_.ICC().empty());
  JXL_CHECK(metadata_->color_encoding.IsGray() == IsGray());

  if (metadata_->HasAlpha() && alpha().xsize() == 0) {
    JXL_UNREACHABLE("MD alpha_bits %u IB alpha %" PRIuS " x %" PRIuS "\n",
                    metadata_->GetAlphaBits(), alpha().xsize(),
                    alpha().ysize());
  }
  const uint32_t alpha_bits = metadata_->GetAlphaBits();
  JXL_CHECK(alpha_bits <= 32);

  // metadata_->num_extra_channels may temporarily differ from
  // extra_channels_.size(), e.g. after SetAlpha. They are synced by the next
  // call to VisitFields.
}

void ImageBundle::VerifySizes() const {
  const size_t xs = xsize();
  const size_t ys = ysize();

  if (HasExtraChannels()) {
    JXL_CHECK(xs != 0 && ys != 0);
    for (const ImageF& ec : extra_channels_) {
      JXL_CHECK(ec.xsize() == xs);
      JXL_CHECK(ec.ysize() == ys);
    }
  }
}

size_t ImageBundle::DetectRealBitdepth() const {
  return metadata_->bit_depth.bits_per_sample;

  // TODO(lode): let this function return lower bit depth if possible, e.g.
  // return 8 bits in case the original image came from a 16-bit PNG that
  // was in fact representable as 8-bit PNG. Ensure that the implementation
  // returns 16 if e.g. two consecutive 16-bit values appeared in the original
  // image (such as 32768 and 32769), take into account that e.g. the values
  // 3-bit can represent is not a superset of the values 2-bit can represent,
  // and there may be slight imprecisions in the floating point image.
}

const ImageF& ImageBundle::black() const {
  JXL_ASSERT(HasBlack());
  const size_t ec = metadata_->Find(ExtraChannel::kBlack) -
                    metadata_->extra_channel_info.data();
  JXL_ASSERT(ec < extra_channels_.size());
  return extra_channels_[ec];
}
const ImageF& ImageBundle::alpha() const {
  JXL_ASSERT(HasAlpha());
  const size_t ec = metadata_->Find(ExtraChannel::kAlpha) -
                    metadata_->extra_channel_info.data();
  JXL_ASSERT(ec < extra_channels_.size());
  return extra_channels_[ec];
}
ImageF* ImageBundle::alpha() {
  JXL_ASSERT(HasAlpha());
  const size_t ec = metadata_->Find(ExtraChannel::kAlpha) -
                    metadata_->extra_channel_info.data();
  JXL_ASSERT(ec < extra_channels_.size());
  return &extra_channels_[ec];
}

void ImageBundle::SetAlpha(ImageF&& alpha) {
  const ExtraChannelInfo* eci = metadata_->Find(ExtraChannel::kAlpha);
  // Must call SetAlphaBits first, otherwise we don't know which channel index
  JXL_CHECK(eci != nullptr);
  JXL_CHECK(alpha.xsize() != 0 && alpha.ysize() != 0);
  if (extra_channels_.size() < metadata_->extra_channel_info.size()) {
    // TODO(jon): get rid of this case
    extra_channels_.insert(
        extra_channels_.begin() + (eci - metadata_->extra_channel_info.data()),
        std::move(alpha));
  } else {
    extra_channels_[eci - metadata_->extra_channel_info.data()] =
        std::move(alpha);
  }
  // num_extra_channels is automatically set in visitor
  VerifySizes();
}

void ImageBundle::SetExtraChannels(std::vector<ImageF>&& extra_channels) {
  for (const ImageF& plane : extra_channels) {
    JXL_CHECK(plane.xsize() != 0 && plane.ysize() != 0);
  }
  extra_channels_ = std::move(extra_channels);
  VerifySizes();
}
}  // namespace jxl
