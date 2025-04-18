// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef LIB_JXL_MATRIX_OPS_H_
#define LIB_JXL_MATRIX_OPS_H_

// 3x3 matrix operations.

#include <cmath>  // abs
#include <cstddef>

#include "lib/jxl/base/status.h"

namespace jxl {

// Computes C = A * B, where A, B, C are 3x3 matrices.
template <typename T>
void Mul3x3Matrix(const T* a, const T* b, T* c) {
  alignas(16) T temp[3];  // For transposed column
  for (size_t x = 0; x < 3; x++) {
    for (size_t z = 0; z < 3; z++) {
      temp[z] = b[z * 3 + x];
    }
    for (size_t y = 0; y < 3; y++) {
      double e = 0;
      for (size_t z = 0; z < 3; z++) {
        e += a[y * 3 + z] * temp[z];
      }
      c[y * 3 + x] = e;
    }
  }
}

// Computes C = A * B, where A is 3x3 matrix and B is vector.
template <typename T>
void Mul3x3Vector(const T* a, const T* b, T* c) {
  for (size_t y = 0; y < 3; y++) {
    double e = 0;
    for (size_t x = 0; x < 3; x++) {
      e += a[y * 3 + x] * b[x];
    }
    c[y] = e;
  }
}

// Inverts a 3x3 matrix in place.
template <typename T>
Status Inv3x3Matrix(T* matrix) {
  // Intermediate computation is done in double precision.
  double temp[9];
  temp[0] = static_cast<double>(matrix[4]) * matrix[8] -
            static_cast<double>(matrix[5]) * matrix[7];
  temp[1] = static_cast<double>(matrix[2]) * matrix[7] -
            static_cast<double>(matrix[1]) * matrix[8];
  temp[2] = static_cast<double>(matrix[1]) * matrix[5] -
            static_cast<double>(matrix[2]) * matrix[4];
  temp[3] = static_cast<double>(matrix[5]) * matrix[6] -
            static_cast<double>(matrix[3]) * matrix[8];
  temp[4] = static_cast<double>(matrix[0]) * matrix[8] -
            static_cast<double>(matrix[2]) * matrix[6];
  temp[5] = static_cast<double>(matrix[2]) * matrix[3] -
            static_cast<double>(matrix[0]) * matrix[5];
  temp[6] = static_cast<double>(matrix[3]) * matrix[7] -
            static_cast<double>(matrix[4]) * matrix[6];
  temp[7] = static_cast<double>(matrix[1]) * matrix[6] -
            static_cast<double>(matrix[0]) * matrix[7];
  temp[8] = static_cast<double>(matrix[0]) * matrix[4] -
            static_cast<double>(matrix[1]) * matrix[3];
  double det = matrix[0] * temp[0] + matrix[1] * temp[3] + matrix[2] * temp[6];
  if (std::abs(det) < 1e-10) {
    return JXL_FAILURE("Matrix determinant is too close to 0");
  }
  double idet = 1.0 / det;
  for (size_t i = 0; i < 9; i++) {
    matrix[i] = temp[i] * idet;
  }
  return true;
}

}  // namespace jxl

#endif  // LIB_JXL_MATRIX_OPS_H_
