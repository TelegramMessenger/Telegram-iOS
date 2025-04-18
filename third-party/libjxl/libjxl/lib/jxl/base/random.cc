// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/jxl/base/random.h"

#include <cmath>

namespace jxl {

Rng::GeometricDistribution::GeometricDistribution(float p)
    : inv_log_1mp(1.0 / std::log(1 - p)) {}

uint32_t Rng::Geometric(const GeometricDistribution& dist) {
  float f = UniformF(0, 1);
  float log = std::log(1 - f) * dist.inv_log_1mp;
  return static_cast<uint32_t>(log);
}

}  // namespace jxl
