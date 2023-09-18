// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include <stdint.h>

#include "lib/jxl/dec_bit_reader.h"
#include "lib/jxl/frame_header.h"
#include "lib/jxl/headers.h"
#include "lib/jxl/image_bundle.h"
#include "lib/jxl/jpeg/jpeg_data.h"
#include "lib/jxl/loop_filter.h"
#include "lib/jxl/modular/encoding/context_predict.h"
#include "lib/jxl/modular/encoding/encoding.h"
#include "lib/jxl/modular/transform/transform.h"

namespace jpegxl {
namespace tools {

using ::jxl::BitReader;
using ::jxl::CodecMetadata;
using ::jxl::CustomTransformData;
using ::jxl::ImageMetadata;
using ::jxl::SizeHeader;
using ::jxl::Span;

int TestOneInput(const uint8_t* data, size_t size) {
  // Global parameters used by some headers.
  CodecMetadata codec_metadata;

  // First byte controls which header to parse.
  if (size == 0) return 0;
  BitReader reader(Span<const uint8_t>(data + 1, size - 1));
#define FUZZER_CASE_HEADER(number, classname, ...) \
  case number: {                                   \
    ::jxl::classname header{__VA_ARGS__};          \
    (void)jxl::Bundle::Read(&reader, &header);     \
    break;                                         \
  }
  switch (data[0]) {
    case 0: {
      SizeHeader size_header;
      (void)jxl::ReadSizeHeader(&reader, &size_header);
      break;
    }

    case 1: {
      ImageMetadata metadata;
      (void)jxl::ReadImageMetadata(&reader, &metadata);
      break;
    }

      FUZZER_CASE_HEADER(2, FrameHeader, &codec_metadata)
      FUZZER_CASE_HEADER(3, jpeg::JPEGData)
      FUZZER_CASE_HEADER(4, AnimationFrame, &codec_metadata)
      FUZZER_CASE_HEADER(5, AnimationHeader)
      FUZZER_CASE_HEADER(6, BitDepth)
      FUZZER_CASE_HEADER(7, BlendingInfo)
      FUZZER_CASE_HEADER(8, ColorEncoding)
      FUZZER_CASE_HEADER(9, CustomTransferFunction)
      FUZZER_CASE_HEADER(10, Customxy)
      FUZZER_CASE_HEADER(11, ExtraChannelInfo)
      FUZZER_CASE_HEADER(12, GroupHeader)
      FUZZER_CASE_HEADER(13, weighted::Header)
      FUZZER_CASE_HEADER(14, LoopFilter)
      FUZZER_CASE_HEADER(15, LZ77Params)
      FUZZER_CASE_HEADER(16, OpsinInverseMatrix)
      FUZZER_CASE_HEADER(17, Passes)
      FUZZER_CASE_HEADER(18, PreviewHeader)
      FUZZER_CASE_HEADER(19, QuantizerParams)
      FUZZER_CASE_HEADER(20, SqueezeParams)
      FUZZER_CASE_HEADER(21, ToneMapping)
      FUZZER_CASE_HEADER(22, Transform)
      FUZZER_CASE_HEADER(23, YCbCrChromaSubsampling)

    default: {
      CustomTransformData transform_data;
      transform_data.nonserialized_xyb_encoded = true;
      (void)jxl::Bundle::Read(&reader, &transform_data);
      break;
    }
  }
  (void)reader.Close();

  return 0;
}

}  // namespace tools
}  // namespace jpegxl

extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size) {
  return jpegxl::tools::TestOneInput(data, size);
}
