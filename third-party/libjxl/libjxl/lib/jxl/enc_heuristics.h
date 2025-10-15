// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef LIB_JXL_ENC_HEURISTICS_H_
#define LIB_JXL_ENC_HEURISTICS_H_

// Hook for custom encoder heuristics (VarDCT only for now).

#include <jxl/cms_interface.h>
#include <stddef.h>
#include <stdint.h>

#include <string>

#include "lib/jxl/base/data_parallel.h"
#include "lib/jxl/base/status.h"
#include "lib/jxl/image.h"
#include "lib/jxl/modular/encoding/enc_ma.h"

namespace jxl {

struct AuxOut;
struct PassesEncoderState;
class DequantMatrices;
class ImageBundle;
class ModularFrameEncoder;

class EncoderHeuristics {
 public:
  virtual ~EncoderHeuristics() = default;
  // Initializes encoder structures in `enc_state` using the original image data
  // in `original_pixels`, and the XYB image data in `opsin`. Also modifies the
  // `opsin` image by applying Gaborish, and doing other modifications if
  // necessary. `pool` is used for running the computations on multiple threads.
  // `aux_out` collects statistics and can be used to print debug images.
  virtual Status LossyFrameHeuristics(
      PassesEncoderState* enc_state, ModularFrameEncoder* modular_frame_encoder,
      const ImageBundle* original_pixels, Image3F* opsin,
      const JxlCmsInterface& cms, ThreadPool* pool, AuxOut* aux_out) = 0;

  // Custom fixed tree for lossless mode. Must set `tree` to a valid tree if
  // the function returns true.
  virtual bool CustomFixedTreeLossless(const FrameDimensions& frame_dim,
                                       Tree* tree) {
    return false;
  }

  // If this method returns `true`, the `opsin` parameter to
  // LossyFrameHeuristics will not be initialized, and should be initialized
  // during the call. Moreover, `original_pixels` may not be in a linear
  // colorspace (but will be the same as the `ib` value passed to this
  // function).
  virtual bool HandlesColorConversion(const CompressParams& cparams,
                                      const ImageBundle& ib) {
    return false;
  }
};

class DefaultEncoderHeuristics : public EncoderHeuristics {
 public:
  Status LossyFrameHeuristics(PassesEncoderState* enc_state,
                              ModularFrameEncoder* modular_frame_encoder,
                              const ImageBundle* original_pixels,
                              Image3F* opsin, const JxlCmsInterface& cms,
                              ThreadPool* pool, AuxOut* aux_out) override;
  bool HandlesColorConversion(const CompressParams& cparams,
                              const ImageBundle& ib) override;
};

// Exposed here since it may be used by other EncoderHeuristics implementations
// outside this project.
void FindBestDequantMatrices(const CompressParams& cparams,
                             const Image3F& opsin,
                             ModularFrameEncoder* modular_frame_encoder,
                             DequantMatrices* dequant_matrices);

}  // namespace jxl

#endif  // LIB_JXL_ENC_HEURISTICS_H_
