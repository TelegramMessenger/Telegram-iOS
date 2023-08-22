// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/extras/enc/exr.h"

#if JPEGXL_ENABLE_EXR
#include <ImfChromaticitiesAttribute.h>
#include <ImfIO.h>
#include <ImfRgbaFile.h>
#include <ImfStandardAttributes.h>
#endif
#include <jxl/codestream_header.h>

#include <vector>

#include "lib/extras/packed_image.h"
#include "lib/jxl/base/byte_order.h"

namespace jxl {
namespace extras {

#if JPEGXL_ENABLE_EXR
namespace {

namespace OpenEXR = OPENEXR_IMF_NAMESPACE;
namespace Imath = IMATH_NAMESPACE;

// OpenEXR::Int64 is deprecated in favor of using uint64_t directly, but using
// uint64_t as recommended causes build failures with previous OpenEXR versions
// on macOS, where the definition for OpenEXR::Int64 was actually not equivalent
// to uint64_t. This alternative should work in all cases.
using ExrInt64 = decltype(std::declval<OpenEXR::IStream>().tellg());

class InMemoryOStream : public OpenEXR::OStream {
 public:
  // `bytes` must outlive the InMemoryOStream.
  explicit InMemoryOStream(std::vector<uint8_t>* const bytes)
      : OStream(/*fileName=*/""), bytes_(*bytes) {}

  void write(const char c[], const int n) override {
    if (bytes_.size() < pos_ + n) {
      bytes_.resize(pos_ + n);
    }
    std::copy_n(c, n, bytes_.begin() + pos_);
    pos_ += n;
  }

  ExrInt64 tellp() override { return pos_; }
  void seekp(const ExrInt64 pos) override {
    if (bytes_.size() + 1 < pos) {
      bytes_.resize(pos - 1);
    }
    pos_ = pos;
  }

 private:
  std::vector<uint8_t>& bytes_;
  size_t pos_ = 0;
};

// Loads a Big-Endian float
float LoadBEFloat(const uint8_t* p) {
  uint32_t u = LoadBE32(p);
  float result;
  memcpy(&result, &u, 4);
  return result;
}

// Loads a Little-Endian float
float LoadLEFloat(const uint8_t* p) {
  uint32_t u = LoadLE32(p);
  float result;
  memcpy(&result, &u, 4);
  return result;
}

Status EncodeImageEXR(const PackedImage& image, const JxlBasicInfo& info,
                      const JxlColorEncoding& c_enc, ThreadPool* pool,
                      std::vector<uint8_t>* bytes) {
  OpenEXR::setGlobalThreadCount(0);

  const size_t xsize = info.xsize;
  const size_t ysize = info.ysize;
  const bool has_alpha = info.alpha_bits > 0;
  const bool alpha_is_premultiplied = info.alpha_premultiplied;

  if (info.num_color_channels != 3 ||
      c_enc.color_space != JXL_COLOR_SPACE_RGB ||
      c_enc.transfer_function != JXL_TRANSFER_FUNCTION_LINEAR) {
    return JXL_FAILURE("Unsupported color encoding for OpenEXR output.");
  }

  const size_t num_channels = 3 + (has_alpha ? 1 : 0);
  const JxlPixelFormat format = image.format;

  if (format.data_type != JXL_TYPE_FLOAT) {
    return JXL_FAILURE("Unsupported pixel format for OpenEXR output");
  }

  const uint8_t* in = reinterpret_cast<const uint8_t*>(image.pixels());
  size_t in_stride = num_channels * 4 * xsize;

  OpenEXR::Header header(xsize, ysize);
  OpenEXR::Chromaticities chromaticities;
  chromaticities.red =
      Imath::V2f(c_enc.primaries_red_xy[0], c_enc.primaries_red_xy[1]);
  chromaticities.green =
      Imath::V2f(c_enc.primaries_green_xy[0], c_enc.primaries_green_xy[1]);
  chromaticities.blue =
      Imath::V2f(c_enc.primaries_blue_xy[0], c_enc.primaries_blue_xy[1]);
  chromaticities.white =
      Imath::V2f(c_enc.white_point_xy[0], c_enc.white_point_xy[1]);
  OpenEXR::addChromaticities(header, chromaticities);
  OpenEXR::addWhiteLuminance(header, info.intensity_target);

  auto loadFloat =
      format.endianness == JXL_BIG_ENDIAN ? LoadBEFloat : LoadLEFloat;
  auto loadAlpha =
      has_alpha ? loadFloat : [](const uint8_t* p) -> float { return 1.0f; };

  // Ensure that the destructor of RgbaOutputFile has run before we look at the
  // size of `bytes`.
  {
    InMemoryOStream os(bytes);
    OpenEXR::RgbaOutputFile output(
        os, header, has_alpha ? OpenEXR::WRITE_RGBA : OpenEXR::WRITE_RGB);
    // How many rows to write at once. Again, the OpenEXR documentation
    // recommends writing the whole image in one call.
    const int y_chunk_size = ysize;
    std::vector<OpenEXR::Rgba> output_rows(xsize * y_chunk_size);

    for (size_t start_y = 0; start_y < ysize; start_y += y_chunk_size) {
      // Inclusive.
      const size_t end_y = std::min(start_y + y_chunk_size - 1, ysize - 1);
      output.setFrameBuffer(output_rows.data() - start_y * xsize,
                            /*xStride=*/1, /*yStride=*/xsize);
      for (size_t y = start_y; y <= end_y; ++y) {
        const uint8_t* in_row = &in[(y - start_y) * in_stride];
        OpenEXR::Rgba* const JXL_RESTRICT row_data =
            &output_rows[(y - start_y) * xsize];
        for (size_t x = 0; x < xsize; ++x) {
          const uint8_t* in_pixel = &in_row[4 * num_channels * x];
          float r = loadFloat(&in_pixel[0]);
          float g = loadFloat(&in_pixel[4]);
          float b = loadFloat(&in_pixel[8]);
          const float alpha = loadAlpha(&in_pixel[12]);
          if (!alpha_is_premultiplied) {
            r *= alpha;
            g *= alpha;
            b *= alpha;
          }
          row_data[x] = OpenEXR::Rgba(r, g, b, alpha);
        }
      }
      output.writePixels(/*numScanLines=*/end_y - start_y + 1);
    }
  }

  return true;
}

class EXREncoder : public Encoder {
  std::vector<JxlPixelFormat> AcceptedFormats() const override {
    std::vector<JxlPixelFormat> formats;
    for (const uint32_t num_channels : {1, 2, 3, 4}) {
      for (const JxlDataType data_type : {JXL_TYPE_FLOAT}) {
        for (JxlEndianness endianness : {JXL_BIG_ENDIAN, JXL_LITTLE_ENDIAN}) {
          formats.push_back(JxlPixelFormat{/*num_channels=*/num_channels,
                                           /*data_type=*/data_type,
                                           /*endianness=*/endianness,
                                           /*align=*/0});
        }
      }
    }
    return formats;
  }
  Status Encode(const PackedPixelFile& ppf, EncodedImage* encoded_image,
                ThreadPool* pool = nullptr) const override {
    JXL_RETURN_IF_ERROR(VerifyBasicInfo(ppf.info));
    encoded_image->icc.clear();
    encoded_image->bitstreams.clear();
    encoded_image->bitstreams.reserve(ppf.frames.size());
    for (const auto& frame : ppf.frames) {
      JXL_RETURN_IF_ERROR(VerifyPackedImage(frame.color, ppf.info));
      encoded_image->bitstreams.emplace_back();
      JXL_RETURN_IF_ERROR(EncodeImageEXR(frame.color, ppf.info,
                                         ppf.color_encoding, pool,
                                         &encoded_image->bitstreams.back()));
    }
    return true;
  }
};

}  // namespace
#endif

std::unique_ptr<Encoder> GetEXREncoder() {
#if JPEGXL_ENABLE_EXR
  return jxl::make_unique<EXREncoder>();
#else
  return nullptr;
#endif
}

}  // namespace extras
}  // namespace jxl
