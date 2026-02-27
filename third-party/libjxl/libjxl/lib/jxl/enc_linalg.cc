// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/jxl/enc_linalg.h"

#include <cmath>

#include "lib/jxl/base/compiler_specific.h"
#include "lib/jxl/base/status.h"

namespace jxl {

void ConvertToDiagonal(const ImageD& A, ImageD* const JXL_RESTRICT diag,
                       ImageD* const JXL_RESTRICT U) {
#if JXL_ENABLE_ASSERT
  JXL_ASSERT(A.xsize() == 2);
  JXL_ASSERT(A.ysize() == 2);
  JXL_ASSERT(std::abs(A.Row(0)[1] - A.Row(1)[0]) < 1e-15);
#endif

  if (std::abs(A.ConstRow(0)[1]) < 1e-15) {
    // Already diagonal.
    diag->Row(0)[0] = A.ConstRow(0)[0];
    diag->Row(0)[1] = A.ConstRow(1)[1];
    U->Row(0)[0] = U->Row(1)[1] = 1.0;
    U->Row(0)[1] = U->Row(1)[0] = 0.0;
    return;
  }
  double b = -(A.Row(0)[0] + A.Row(1)[1]);
  double c = A.Row(0)[0] * A.Row(1)[1] - A.Row(0)[1] * A.Row(0)[1];
  double d = b * b - 4.0 * c;
  double sqd = std::sqrt(d);
  double l1 = (-b - sqd) * 0.5;
  double l2 = (-b + sqd) * 0.5;

  double v1[2] = {A.Row(0)[0] - l1, A.Row(1)[0]};
  double v1n = 1.0 / std::hypot(v1[0], v1[1]);
  v1[0] = v1[0] * v1n;
  v1[1] = v1[1] * v1n;

  diag->Row(0)[0] = l1;
  diag->Row(0)[1] = l2;

  U->Row(0)[0] = v1[1];
  U->Row(0)[1] = -v1[0];
  U->Row(1)[0] = v1[0];
  U->Row(1)[1] = v1[1];
}

}  // namespace jxl
