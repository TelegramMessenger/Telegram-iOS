// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef LIB_JXL_LINALG_H_
#define LIB_JXL_LINALG_H_

// Linear algebra.

#include "lib/jxl/base/compiler_specific.h"
#include "lib/jxl/image.h"

namespace jxl {

using ImageD = Plane<double>;

// A is symmetric, U is orthogonal, and A = U * Diagonal(diag) * Transpose(U).
void ConvertToDiagonal(const ImageD& A, ImageD* JXL_RESTRICT diag,
                       ImageD* JXL_RESTRICT U);

}  // namespace jxl

#endif  // LIB_JXL_LINALG_H_
