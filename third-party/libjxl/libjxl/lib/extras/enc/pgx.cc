// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/extras/enc/pgx.h"

#include <jxl/codestream_header.h>
#include <stdio.h>
#include <string.h>

#include "lib/extras/packed_image.h"
#include "lib/jxl/base/byte_order.h"

namespace jxl {
namespace extras {
namespace {

constexpr size_t kMaxHeaderSize = 200;

Status EncodeHeader(const JxlBasicInfo& info, char* header,
                    int* chars_written) {
  if (info.alpha_bits > 0) {
    return JXL_FAILURE("PGX: can't store alpha");
  }
  if (info.num_color_channels != 1) {
    return JXL_FAILURE("PGX: must be grayscale");
  }
  // TODO(lode): verify other bit depths: for other bit depths such as 1 or 4
  // bits, have a test case to verify it works correctly. For bits > 16, we may
  // need to change the way external_image works.
  if (info.bits_per_sample != 8 && info.bits_per_sample != 16) {
    return JXL_FAILURE("PGX: bits other than 8 or 16 not yet supported");
  }

  // Use ML (Big Endian), LM may not be well supported by all decoders.
  *chars_written = snprintf(header, kMaxHeaderSize, "PG ML + %u %u %u\n",
                            info.bits_per_sample, info.xsize, info.ysize);
  JXL_RETURN_IF_ERROR(static_cast<unsigned int>(*chars_written) <
                      kMaxHeaderSize);
  return true;
}

Status EncodeImagePGX(const PackedFrame& frame, const JxlBasicInfo& info,
                      std::vector<uint8_t>* bytes) {
  char header[kMaxHeaderSize];
  int header_size = 0;
  JXL_RETURN_IF_ERROR(EncodeHeader(info, header, &header_size));

  const PackedImage& color = frame.color;
  const JxlPixelFormat format = color.format;
  const uint8_t* in = reinterpret_cast<const uint8_t*>(color.pixels());
  size_t data_bits_per_sample = PackedImage::BitsPerChannel(format.data_type);
  size_t bytes_per_sample = data_bits_per_sample / kBitsPerByte;
  size_t num_samples = info.xsize * info.ysize;

  if (info.bits_per_sample != data_bits_per_sample) {
    return JXL_FAILURE("Bit depth does not match pixel data type");
  }

  std::vector<uint8_t> pixels(num_samples * bytes_per_sample);

  if (format.data_type == JXL_TYPE_UINT8) {
    memcpy(&pixels[0], in, num_samples * bytes_per_sample);
  } else if (format.data_type == JXL_TYPE_UINT16) {
    if (format.endianness != JXL_BIG_ENDIAN) {
      const uint8_t* p_in = in;
      uint8_t* p_out = pixels.data();
      for (size_t i = 0; i < num_samples; ++i, p_in += 2, p_out += 2) {
        StoreBE16(LoadLE16(p_in), p_out);
      }
    } else {
      memcpy(&pixels[0], in, num_samples * bytes_per_sample);
    }
  } else {
    return JXL_FAILURE("Unsupported pixel data type");
  }

  bytes->resize(static_cast<size_t>(header_size) + pixels.size());
  memcpy(bytes->data(), header, static_cast<size_t>(header_size));
  memcpy(bytes->data() + header_size, pixels.data(), pixels.size());

  return true;
}

class PGXEncoder : public Encoder {
 public:
  std::vector<JxlPixelFormat> AcceptedFormats() const override {
    std::vector<JxlPixelFormat> formats;
    for (const JxlDataType data_type : {JXL_TYPE_UINT8, JXL_TYPE_UINT16}) {
      for (JxlEndianness endianness : {JXL_BIG_ENDIAN, JXL_LITTLE_ENDIAN}) {
        formats.push_back(JxlPixelFormat{/*num_channels=*/1,
                                         /*data_type=*/data_type,
                                         /*endianness=*/endianness,
                                         /*align=*/0});
      }
    }
    return formats;
  }
  Status Encode(const PackedPixelFile& ppf, EncodedImage* encoded_image,
                ThreadPool* pool) const override {
    JXL_RETURN_IF_ERROR(VerifyBasicInfo(ppf.info));
    encoded_image->icc.assign(ppf.icc.begin(), ppf.icc.end());
    encoded_image->bitstreams.clear();
    encoded_image->bitstreams.reserve(ppf.frames.size());
    for (const auto& frame : ppf.frames) {
      JXL_RETURN_IF_ERROR(VerifyPackedImage(frame.color, ppf.info));
      encoded_image->bitstreams.emplace_back();
      JXL_RETURN_IF_ERROR(
          EncodeImagePGX(frame, ppf.info, &encoded_image->bitstreams.back()));
    }
    return true;
  }
};

}  // namespace

std::unique_ptr<Encoder> GetPGXEncoder() {
  return jxl::make_unique<PGXEncoder>();
}

}  // namespace extras
}  // namespace jxl
