// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef LIB_JXL_ENC_JXL_SKCMS_H_
#define LIB_JXL_ENC_JXL_SKCMS_H_

// skcms wrapper to rename the skcms symbols to avoid conflicting names with
// other projects using skcms as well. When using JPEGXL_BUNDLE_SKCMS the
// bundled functions will be renamed from skcms_ to jxl_skcms_

#ifdef SKCMS_API
#error "Must include enc_jxl_skcms.h and not skcms.h directly"
#endif  // SKCMS_API

#if JPEGXL_BUNDLE_SKCMS

#define skcms_252_random_bytes jxl_skcms_252_random_bytes
#define skcms_AdaptToXYZD50 jxl_skcms_AdaptToXYZD50
#define skcms_ApproximateCurve jxl_skcms_ApproximateCurve
#define skcms_ApproximatelyEqualProfiles jxl_skcms_ApproximatelyEqualProfiles
#define skcms_AreApproximateInverses jxl_skcms_AreApproximateInverses
#define skcms_GetCHAD jxl_skcms_GetCHAD
#define skcms_GetTagByIndex jxl_skcms_GetTagByIndex
#define skcms_GetTagBySignature jxl_skcms_GetTagBySignature
#define skcms_GetWTPT jxl_skcms_GetWTPT
#define skcms_Identity_TransferFunction jxl_skcms_Identity_TransferFunction
#define skcms_MakeUsableAsDestination jxl_skcms_MakeUsableAsDestination
#define skcms_MakeUsableAsDestinationWithSingleCurve \
  jxl_skcms_MakeUsableAsDestinationWithSingleCurve
#define skcms_Matrix3x3_concat jxl_skcms_Matrix3x3_concat
#define skcms_Matrix3x3_invert jxl_skcms_Matrix3x3_invert
#define skcms_MaxRoundtripError jxl_skcms_MaxRoundtripError
#define skcms_Parse jxl_skcms_Parse
#define skcms_PrimariesToXYZD50 jxl_skcms_PrimariesToXYZD50
#define skcms_sRGB_Inverse_TransferFunction \
  jxl_skcms_sRGB_Inverse_TransferFunction
#define skcms_sRGB_profile jxl_skcms_sRGB_profile
#define skcms_sRGB_TransferFunction jxl_skcms_sRGB_TransferFunction
#define skcms_TransferFunction_eval jxl_skcms_TransferFunction_eval
#define skcms_TransferFunction_invert jxl_skcms_TransferFunction_invert
#define skcms_TransferFunction_makeHLGish jxl_skcms_TransferFunction_makeHLGish
#define skcms_TransferFunction_makePQish jxl_skcms_TransferFunction_makePQish
#define skcms_Transform jxl_skcms_Transform
#define skcms_TransformWithPalette jxl_skcms_TransformWithPalette
#define skcms_TRCs_AreApproximateInverse jxl_skcms_TRCs_AreApproximateInverse
#define skcms_XYZD50_profile jxl_skcms_XYZD50_profile

#endif  // JPEGXL_BUNDLE_SKCMS

#include "skcms.h"

#endif  // LIB_JXL_ENC_JXL_SKCMS_H_
