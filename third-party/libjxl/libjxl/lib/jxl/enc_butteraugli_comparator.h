// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef LIB_JXL_ENC_BUTTERAUGLI_COMPARATOR_H_
#define LIB_JXL_ENC_BUTTERAUGLI_COMPARATOR_H_

#include <jxl/cms_interface.h>
#include <stddef.h>

#include <memory>

#include "lib/jxl/base/data_parallel.h"
#include "lib/jxl/base/status.h"
#include "lib/jxl/butteraugli/butteraugli.h"
#include "lib/jxl/enc_comparator.h"
#include "lib/jxl/image.h"
#include "lib/jxl/image_bundle.h"

namespace jxl {

class JxlButteraugliComparator : public Comparator {
 public:
  explicit JxlButteraugliComparator(const ButteraugliParams& params,
                                    const JxlCmsInterface& cms);

  Status SetReferenceImage(const ImageBundle& ref) override;

  Status CompareWith(const ImageBundle& actual, ImageF* diffmap,
                     float* score) override;

  float GoodQualityScore() const override;
  float BadQualityScore() const override;

 private:
  ButteraugliParams params_;
  JxlCmsInterface cms_;
  std::unique_ptr<ButteraugliComparator> comparator_;
  size_t xsize_ = 0;
  size_t ysize_ = 0;
};

// Returns the butteraugli distance between rgb0 and rgb1.
// If distmap is not null, it must be the same size as rgb0 and rgb1.
float ButteraugliDistance(const ImageBundle& rgb0, const ImageBundle& rgb1,
                          const ButteraugliParams& params,
                          const JxlCmsInterface& cms, ImageF* distmap = nullptr,
                          ThreadPool* pool = nullptr,
                          bool ignore_alpha = false);

float ButteraugliDistance(const std::vector<ImageBundle>& frames0,
                          const std::vector<ImageBundle>& frames1,
                          const ButteraugliParams& params,
                          const JxlCmsInterface& cms, ImageF* distmap = nullptr,
                          ThreadPool* pool = nullptr);

}  // namespace jxl

#endif  // LIB_JXL_ENC_BUTTERAUGLI_COMPARATOR_H_
