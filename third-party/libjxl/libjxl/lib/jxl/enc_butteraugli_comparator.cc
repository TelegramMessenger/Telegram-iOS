// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/jxl/enc_butteraugli_comparator.h"

#include <algorithm>
#include <vector>

#include "lib/jxl/color_management.h"
#include "lib/jxl/enc_image_bundle.h"

namespace jxl {

JxlButteraugliComparator::JxlButteraugliComparator(
    const ButteraugliParams& params, const JxlCmsInterface& cms)
    : params_(params), cms_(cms) {}

Status JxlButteraugliComparator::SetReferenceImage(const ImageBundle& ref) {
  const ImageBundle* ref_linear_srgb;
  ImageMetadata metadata = *ref.metadata();
  ImageBundle store(&metadata);
  if (!TransformIfNeeded(ref, ColorEncoding::LinearSRGB(ref.IsGray()), cms_,
                         /*pool=*/nullptr, &store, &ref_linear_srgb)) {
    return false;
  }

  comparator_.reset(
      new ButteraugliComparator(ref_linear_srgb->color(), params_));
  xsize_ = ref.xsize();
  ysize_ = ref.ysize();
  return true;
}

Status JxlButteraugliComparator::CompareWith(const ImageBundle& actual,
                                             ImageF* diffmap, float* score) {
  if (!comparator_) {
    return JXL_FAILURE("Must set reference image first");
  }
  if (xsize_ != actual.xsize() || ysize_ != actual.ysize()) {
    return JXL_FAILURE("Images must have same size");
  }

  const ImageBundle* actual_linear_srgb;
  ImageMetadata metadata = *actual.metadata();
  ImageBundle store(&metadata);
  if (!TransformIfNeeded(actual, ColorEncoding::LinearSRGB(actual.IsGray()),
                         cms_,
                         /*pool=*/nullptr, &store, &actual_linear_srgb)) {
    return false;
  }

  ImageF temp_diffmap(xsize_, ysize_);
  comparator_->Diffmap(actual_linear_srgb->color(), temp_diffmap);

  if (score != nullptr) {
    *score = ButteraugliScoreFromDiffmap(temp_diffmap, &params_);
  }
  if (diffmap != nullptr) {
    diffmap->Swap(temp_diffmap);
  }

  return true;
}

float JxlButteraugliComparator::GoodQualityScore() const {
  return ButteraugliFuzzyInverse(1.5);
}

float JxlButteraugliComparator::BadQualityScore() const {
  return ButteraugliFuzzyInverse(0.5);
}

float ButteraugliDistance(const ImageBundle& rgb0, const ImageBundle& rgb1,
                          const ButteraugliParams& params,
                          const JxlCmsInterface& cms, ImageF* distmap,
                          ThreadPool* pool, bool ignore_alpha) {
  JxlButteraugliComparator comparator(params, cms);
  return ComputeScore(rgb0, rgb1, &comparator, cms, distmap, pool,
                      ignore_alpha);
}

float ButteraugliDistance(const std::vector<ImageBundle>& frames0,
                          const std::vector<ImageBundle>& frames1,
                          const ButteraugliParams& params,
                          const JxlCmsInterface& cms, ImageF* distmap,
                          ThreadPool* pool) {
  JxlButteraugliComparator comparator(params, cms);
  JXL_ASSERT(frames0.size() == frames1.size());
  float max_dist = 0.0f;
  for (size_t i = 0; i < frames0.size(); ++i) {
    max_dist = std::max(
        max_dist,
        ComputeScore(frames0[i], frames1[i], &comparator, cms, distmap, pool));
  }
  return max_dist;
}

}  // namespace jxl
