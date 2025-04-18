// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef TOOLS_SSIMULACRA_H_
#define TOOLS_SSIMULACRA_H_

#include <vector>

#include "lib/jxl/image.h"

namespace ssimulacra {

struct SsimulacraScale {
  double avg_ssim[3];
  double min_ssim[3];
};

struct Ssimulacra {
  std::vector<SsimulacraScale> scales;
  double avg_edgediff[3];
  double row_p2[2][3];
  double col_p2[2][3];
  bool simple;

  double Score() const;
  void PrintDetails() const;
};

Ssimulacra ComputeDiff(const jxl::Image3F& orig, const jxl::Image3F& distorted,
                       bool simple);

}  // namespace ssimulacra

#endif  // TOOLS_SSIMULACRA_H_
