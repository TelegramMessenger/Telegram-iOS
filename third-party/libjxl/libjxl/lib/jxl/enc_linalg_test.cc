// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/jxl/enc_linalg.h"

#include "lib/jxl/image_test_utils.h"
#include "lib/jxl/testing.h"

namespace jxl {
namespace {

ImageD Identity(const size_t N) {
  ImageD out(N, N);
  for (size_t i = 0; i < N; ++i) {
    double* JXL_RESTRICT row = out.Row(i);
    std::fill(row, row + N, 0);
    row[i] = 1.0;
  }
  return out;
}

ImageD Diagonal(const ImageD& d) {
  JXL_ASSERT(d.ysize() == 1);
  ImageD out(d.xsize(), d.xsize());
  const double* JXL_RESTRICT row_diag = d.Row(0);
  for (size_t k = 0; k < d.xsize(); ++k) {
    double* JXL_RESTRICT row_out = out.Row(k);
    std::fill(row_out, row_out + d.xsize(), 0.0);
    row_out[k] = row_diag[k];
  }
  return out;
}

ImageD MatMul(const ImageD& A, const ImageD& B) {
  JXL_ASSERT(A.ysize() == B.xsize());
  ImageD out(A.xsize(), B.ysize());
  for (size_t y = 0; y < B.ysize(); ++y) {
    const double* const JXL_RESTRICT row_b = B.Row(y);
    double* const JXL_RESTRICT row_out = out.Row(y);
    for (size_t x = 0; x < A.xsize(); ++x) {
      row_out[x] = 0.0;
      for (size_t k = 0; k < B.xsize(); ++k) {
        row_out[x] += A.Row(k)[x] * row_b[k];
      }
    }
  }
  return out;
}

ImageD Transpose(const ImageD& A) {
  ImageD out(A.ysize(), A.xsize());
  for (size_t x = 0; x < A.xsize(); ++x) {
    double* const JXL_RESTRICT row_out = out.Row(x);
    for (size_t y = 0; y < A.ysize(); ++y) {
      row_out[y] = A.Row(y)[x];
    }
  }
  return out;
}

ImageD RandomSymmetricMatrix(const size_t N, Rng& rng, const double vmin,
                             const double vmax) {
  ImageD A(N, N);
  GenerateImage(rng, &A, vmin, vmax);
  for (size_t i = 0; i < N; ++i) {
    for (size_t j = 0; j < i; ++j) {
      A.Row(j)[i] = A.Row(i)[j];
    }
  }
  return A;
}

void VerifyMatrixEqual(const ImageD& A, const ImageD& B, const double eps) {
  ASSERT_EQ(A.xsize(), B.xsize());
  ASSERT_EQ(A.ysize(), B.ysize());
  for (size_t y = 0; y < A.ysize(); ++y) {
    for (size_t x = 0; x < A.xsize(); ++x) {
      ASSERT_NEAR(A.Row(y)[x], B.Row(y)[x], eps);
    }
  }
}

void VerifyOrthogonal(const ImageD& A, const double eps) {
  VerifyMatrixEqual(Identity(A.xsize()), MatMul(Transpose(A), A), eps);
}

TEST(LinAlgTest, ConvertToDiagonal) {
  {
    ImageD I = Identity(2);
    ImageD U(2, 2), d(2, 1);
    ConvertToDiagonal(I, &d, &U);
    VerifyMatrixEqual(I, U, 1e-15);
    for (size_t k = 0; k < 2; ++k) {
      ASSERT_NEAR(d.Row(0)[k], 1.0, 1e-15);
    }
  }
  {
    ImageD A = Identity(2);
    A.Row(0)[1] = A.Row(1)[0] = 2.0;
    ImageD U(2, 2), d(2, 1);
    ConvertToDiagonal(A, &d, &U);
    VerifyOrthogonal(U, 1e-12);
    VerifyMatrixEqual(A, MatMul(U, MatMul(Diagonal(d), Transpose(U))), 1e-12);
  }
  Rng rng(0);
  for (size_t i = 0; i < 100; ++i) {
    ImageD A = RandomSymmetricMatrix(2, rng, -1.0, 1.0);
    ImageD U(2, 2), d(2, 1);
    ConvertToDiagonal(A, &d, &U);
    VerifyOrthogonal(U, 1e-12);
    VerifyMatrixEqual(A, MatMul(U, MatMul(Diagonal(d), Transpose(U))), 1e-12);
  }
}

}  // namespace
}  // namespace jxl
