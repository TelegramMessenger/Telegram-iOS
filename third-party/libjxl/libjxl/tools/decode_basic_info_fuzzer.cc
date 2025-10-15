// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include <jxl/decode.h>
#include <stdint.h>

namespace jpegxl {
namespace tools {

int TestOneInput(const uint8_t* data, size_t size) {
  JxlDecoderStatus status;
  JxlDecoder* dec = JxlDecoderCreate(nullptr);
  JxlDecoderSubscribeEvents(dec, JXL_DEC_BASIC_INFO | JXL_DEC_COLOR_ENCODING);
  JxlDecoderSetInput(dec, data, size);

  status = JxlDecoderProcessInput(dec);

  if (status != JXL_DEC_BASIC_INFO) {
    JxlDecoderDestroy(dec);
    return 0;
  }

  JxlBasicInfo info;
  bool have_basic_info = !JxlDecoderGetBasicInfo(dec, &info);

  if (have_basic_info) {
    if (info.alpha_bits != 0) {
      for (int i = 0; i < info.num_extra_channels; ++i) {
        JxlExtraChannelInfo extra;
        JxlDecoderGetExtraChannelInfo(dec, 0, &extra);
      }
    }
  }
  status = JxlDecoderProcessInput(dec);

  if (status != JXL_DEC_COLOR_ENCODING) {
    JxlDecoderDestroy(dec);
    return 0;
  }

  JxlDecoderGetColorAsEncodedProfile(dec, JXL_COLOR_PROFILE_TARGET_ORIGINAL,
                                     nullptr);
  size_t dec_profile_size;
  JxlDecoderGetICCProfileSize(dec, JXL_COLOR_PROFILE_TARGET_ORIGINAL,
                              &dec_profile_size);

  JxlDecoderDestroy(dec);
  return 0;
}

}  // namespace tools
}  // namespace jpegxl

extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size) {
  return jpegxl::tools::TestOneInput(data, size);
}
