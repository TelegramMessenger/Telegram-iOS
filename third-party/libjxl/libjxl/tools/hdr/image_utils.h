// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef TOOLS_HDR_IMAGE_UTILS_H_
#define TOOLS_HDR_IMAGE_UTILS_H_

#include <jxl/cms_interface.h>

#include "lib/jxl/base/status.h"
#include "lib/jxl/codec_in_out.h"
#include "lib/jxl/image_bundle.h"

namespace jpegxl {
namespace tools {

static inline jxl::Status TransformCodecInOutTo(
    jxl::CodecInOut& io, const jxl::ColorEncoding& c_desired,
    jxl::ThreadPool* pool) {
  const JxlCmsInterface& cms = jxl::GetJxlCms();
  if (io.metadata.m.have_preview) {
    JXL_RETURN_IF_ERROR(io.preview_frame.TransformTo(c_desired, cms, pool));
  }
  for (jxl::ImageBundle& ib : io.frames) {
    JXL_RETURN_IF_ERROR(ib.TransformTo(c_desired, cms, pool));
  }
  return true;
}

}  // namespace tools
}  // namespace jpegxl

#endif  // TOOLS_HDR_IMAGE_UTILS_H_
