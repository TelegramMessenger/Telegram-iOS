// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef LIB_JXL_DEC_XYB_H_
#define LIB_JXL_DEC_XYB_H_

// XYB -> linear sRGB.

#include "lib/jxl/base/compiler_specific.h"
#include "lib/jxl/base/data_parallel.h"
#include "lib/jxl/base/status.h"
#include "lib/jxl/color_encoding_internal.h"
#include "lib/jxl/dec_bit_reader.h"
#include "lib/jxl/image.h"
#include "lib/jxl/image_metadata.h"
#include "lib/jxl/opsin_params.h"

namespace jxl {

// Parameters for XYB->sRGB conversion.
struct OpsinParams {
  float inverse_opsin_matrix[9 * 4];
  float opsin_biases[4];
  float opsin_biases_cbrt[4];
  float quant_biases[4];
  void Init(float intensity_target);
};

struct OutputEncodingInfo {
  //
  // Fields depending only on image metadata
  //
  ColorEncoding orig_color_encoding;
  // Used for the HLG OOTF and PQ tone mapping.
  float orig_intensity_target;
  // Opsin inverse matrix taken from the metadata.
  float orig_inverse_matrix[9];
  bool default_transform;
  bool xyb_encoded;
  //
  // Fields depending on output color encoding
  //
  ColorEncoding color_encoding;
  bool color_encoding_is_original;
  // Contains an opsin matrix that converts to the primaries of the output
  // encoding.
  OpsinParams opsin_params;
  bool all_default_opsin;
  // Used for Gamma and DCI transfer functions.
  float inverse_gamma;
  // Luminances of color_encoding's primaries, used for the HLG inverse OOTF and
  // for PQ tone mapping.
  // Default to sRGB's.
  float luminances[3];
  // Used for the HLG inverse OOTF and PQ tone mapping.
  float desired_intensity_target;

  Status SetFromMetadata(const CodecMetadata& metadata);
  Status MaybeSetColorEncoding(const ColorEncoding& c_desired);

 private:
  Status SetColorEncoding(const ColorEncoding& c_desired);
};

// Converts `inout` (not padded) from opsin to linear sRGB in-place. Called from
// per-pass postprocessing, hence parallelized.
void OpsinToLinearInplace(Image3F* JXL_RESTRICT inout, ThreadPool* pool,
                          const OpsinParams& opsin_params);

// Converts `opsin:rect` (opsin may be padded, rect.x0 must be vector-aligned)
// to linear sRGB. Called from whole-frame encoder, hence parallelized.
void OpsinToLinear(const Image3F& opsin, const Rect& rect, ThreadPool* pool,
                   Image3F* JXL_RESTRICT linear,
                   const OpsinParams& opsin_params);

// Bt.601 to match JPEG/JFIF. Inputs are _signed_ YCbCr values suitable for DCT,
// see F.1.1.3 of T.81 (because our data type is float, there is no need to add
// a bias to make the values unsigned).
void YcbcrToRgb(const Image3F& ycbcr, Image3F* rgb, const Rect& rect);

bool HasFastXYBTosRGB8();
void FastXYBTosRGB8(const float* input[4], uint8_t* output, bool is_rgba,
                    size_t xsize);

}  // namespace jxl

#endif  // LIB_JXL_DEC_XYB_H_
