// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef TOOLS_SSIMULACRA2_H_
#define TOOLS_SSIMULACRA2_H_

#include <vector>

#include "lib/jxl/image_bundle.h"

struct MsssimScale {
  double avg_ssim[3 * 2];
  double avg_edgediff[3 * 4];
};

struct Msssim {
  std::vector<MsssimScale> scales;

  double Score() const;
};

// Computes the SSIMULACRA 2 score between reference image 'orig' and
// distorted image 'distorted'. In case of alpha transparency, assume
// a gray background if intensity 'bg' (in range 0..1).
Msssim ComputeSSIMULACRA2(const jxl::ImageBundle &orig,
                          const jxl::ImageBundle &distorted, float bg);
Msssim ComputeSSIMULACRA2(const jxl::ImageBundle &orig,
                          const jxl::ImageBundle &distorted);

#endif  // TOOLS_SSIMULACRA2_H_
