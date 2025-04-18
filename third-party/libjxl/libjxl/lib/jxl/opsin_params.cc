// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/jxl/opsin_params.h"

#include <stdlib.h>

#include "lib/jxl/matrix_ops.h"

namespace jxl {

#define INVERSE_OPSIN_FROM_SPEC 1

const float* GetOpsinAbsorbanceInverseMatrix() {
#if INVERSE_OPSIN_FROM_SPEC
  return DefaultInverseOpsinAbsorbanceMatrix();
#else   // INVERSE_OPSIN_FROM_SPEC
  // Compute the inverse opsin matrix from the forward matrix. Less precise
  // than taking the values from the specification, but must be used if the
  // forward transform is changed and the spec will require updating.
  static const float* const kInverse = [] {
    static float inverse[9];
    for (int i = 0; i < 9; i++) {
      inverse[i] = kOpsinAbsorbanceMatrix[i];
    }
    Inv3x3Matrix(inverse);
    return inverse;
  }();
  return kInverse;
#endif  // INVERSE_OPSIN_FROM_SPEC
}

void InitSIMDInverseMatrix(const float* JXL_RESTRICT inverse,
                           float* JXL_RESTRICT simd_inverse,
                           float intensity_target) {
  for (size_t i = 0; i < 9; ++i) {
    simd_inverse[4 * i] = simd_inverse[4 * i + 1] = simd_inverse[4 * i + 2] =
        simd_inverse[4 * i + 3] = inverse[i] * (255.0f / intensity_target);
  }
}

}  // namespace jxl
