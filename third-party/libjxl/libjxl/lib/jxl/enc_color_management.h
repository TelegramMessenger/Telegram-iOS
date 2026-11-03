// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef LIB_JXL_ENC_COLOR_MANAGEMENT_H_
#define LIB_JXL_ENC_COLOR_MANAGEMENT_H_

// ICC profiles and color space conversions.

#include <jxl/cms_interface.h>
#include <stddef.h>
#include <stdint.h>

#include <vector>

#include "lib/jxl/base/padded_bytes.h"
#include "lib/jxl/base/status.h"
#include "lib/jxl/color_encoding_internal.h"
#include "lib/jxl/color_management.h"
#include "lib/jxl/common.h"
#include "lib/jxl/image.h"

namespace jxl {

// Internal C++ wrapper for a JxlCmsInterface.
class ColorSpaceTransform {
 public:
  explicit ColorSpaceTransform(const JxlCmsInterface& cms) : cms_(cms) {}
  ~ColorSpaceTransform() {
    if (cms_data_ != nullptr) {
      cms_.destroy(cms_data_);
    }
  }

  // Cannot copy.
  ColorSpaceTransform(const ColorSpaceTransform&) = delete;
  ColorSpaceTransform& operator=(const ColorSpaceTransform&) = delete;

  Status Init(const ColorEncoding& c_src, const ColorEncoding& c_dst,
              float intensity_target, size_t xsize, size_t num_threads) {
    xsize_ = xsize;
    JxlColorProfile input_profile;
    icc_src_ = c_src.ICC();
    input_profile.icc.data = icc_src_.data();
    input_profile.icc.size = icc_src_.size();
    ConvertInternalToExternalColorEncoding(c_src,
                                           &input_profile.color_encoding);
    input_profile.num_channels = c_src.IsCMYK() ? 4 : c_src.Channels();
    JxlColorProfile output_profile;
    icc_dst_ = c_dst.ICC();
    output_profile.icc.data = icc_dst_.data();
    output_profile.icc.size = icc_dst_.size();
    ConvertInternalToExternalColorEncoding(c_dst,
                                           &output_profile.color_encoding);
    if (c_dst.IsCMYK())
      return JXL_FAILURE("Conversion to CMYK is not supported");
    output_profile.num_channels = c_dst.Channels();
    cms_data_ = cms_.init(cms_.init_data, num_threads, xsize, &input_profile,
                          &output_profile, intensity_target);
    JXL_RETURN_IF_ERROR(cms_data_ != nullptr);
    return true;
  }

  float* BufSrc(const size_t thread) const {
    return cms_.get_src_buf(cms_data_, thread);
  }

  float* BufDst(const size_t thread) const {
    return cms_.get_dst_buf(cms_data_, thread);
  }

  Status Run(const size_t thread, const float* buf_src, float* buf_dst) {
    return cms_.run(cms_data_, thread, buf_src, buf_dst, xsize_);
  }

 private:
  JxlCmsInterface cms_;
  void* cms_data_ = nullptr;
  // The interface may retain pointers into these.
  PaddedBytes icc_src_;
  PaddedBytes icc_dst_;
  size_t xsize_;
};

const JxlCmsInterface& GetJxlCms();

}  // namespace jxl

#endif  // LIB_JXL_ENC_COLOR_MANAGEMENT_H_
