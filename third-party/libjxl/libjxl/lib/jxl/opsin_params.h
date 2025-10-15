// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef LIB_JXL_OPSIN_PARAMS_H_
#define LIB_JXL_OPSIN_PARAMS_H_

// Constants that define the XYB color space.

#include <stdlib.h>

#include <cmath>

#include "lib/jxl/base/compiler_specific.h"

namespace jxl {

// Parameters for opsin absorbance.
static const float kM02 = 0.078f;
static const float kM00 = 0.30f;
static const float kM01 = 1.0f - kM02 - kM00;

static const float kM12 = 0.078f;
static const float kM10 = 0.23f;
static const float kM11 = 1.0f - kM12 - kM10;

static const float kM20 = 0.24342268924547819f;
static const float kM21 = 0.20476744424496821f;
static const float kM22 = 1.0f - kM20 - kM21;

static const float kBScale = 1.0f;
static const float kYToBRatio = 1.0f;  // works better with 0.50017729543783418
static const float kBToYRatio = 1.0f / kYToBRatio;

static const float kB0 = 0.0037930732552754493f;
static const float kB1 = kB0;
static const float kB2 = kB0;

// Opsin absorbance matrix is now frozen.
static const float kOpsinAbsorbanceMatrix[9] = {
    kM00, kM01, kM02, kM10, kM11, kM12, kM20, kM21, kM22,
};

// Must be the inverse matrix of kOpsinAbsorbanceMatrix and match the spec.
static inline const float* DefaultInverseOpsinAbsorbanceMatrix() {
  static float kDefaultInverseOpsinAbsorbanceMatrix[9] = {
      11.031566901960783f,  -9.866943921568629f, -0.16462299647058826f,
      -3.254147380392157f,  4.418770392156863f,  -0.16462299647058826f,
      -3.6588512862745097f, 2.7129230470588235f, 1.9459282392156863f};
  return kDefaultInverseOpsinAbsorbanceMatrix;
}

// Returns 3x3 row-major matrix inverse of kOpsinAbsorbanceMatrix.
// opsin_image_test verifies this is actually the inverse.
const float* GetOpsinAbsorbanceInverseMatrix();

void InitSIMDInverseMatrix(const float* JXL_RESTRICT inverse,
                           float* JXL_RESTRICT simd_inverse,
                           float intensity_target);

static const float kOpsinAbsorbanceBias[3] = {
    kB0,
    kB1,
    kB2,
};

static const float kNegOpsinAbsorbanceBiasRGB[4] = {
    -kOpsinAbsorbanceBias[0], -kOpsinAbsorbanceBias[1],
    -kOpsinAbsorbanceBias[2], 1.0f};

static const float kScaledXYBOffset[3] = {
    0.015386134f,
    0.0f,
    0.27770459f,
};

static const float kScaledXYBScale[3] = {
    22.995788804f,
    1.183000077f,
    1.502141333f,
};

}  // namespace jxl

#endif  // LIB_JXL_OPSIN_PARAMS_H_
