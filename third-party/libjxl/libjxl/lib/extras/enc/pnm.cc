// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/extras/enc/pnm.h"

#include <stdio.h>
#include <string.h>

#include <string>
#include <vector>

#include "lib/extras/packed_image.h"
#include "lib/jxl/base/byte_order.h"
#include "lib/jxl/base/compiler_specific.h"
#include "lib/jxl/base/printf_macros.h"
#include "lib/jxl/base/status.h"
#include "lib/jxl/color_management.h"
#include "lib/jxl/dec_external_image.h"
#include "lib/jxl/enc_color_management.h"
#include "lib/jxl/enc_external_image.h"
#include "lib/jxl/enc_image_bundle.h"
#include "lib/jxl/fields.h"  // AllDefault
#include "lib/jxl/image.h"
#include "lib/jxl/image_bundle.h"

namespace jxl {
namespace extras {
namespace {

constexpr size_t kMaxHeaderSize = 200;

class PNMEncoder : public Encoder {
 public:
  Status Encode(const PackedPixelFile& ppf, EncodedImage* encoded_image,
                ThreadPool* pool = nullptr) const override {
    JXL_RETURN_IF_ERROR(VerifyBasicInfo(ppf.info));
    if (!ppf.metadata.exif.empty() || !ppf.metadata.iptc.empty() ||
        !ppf.metadata.jumbf.empty() || !ppf.metadata.xmp.empty()) {
      JXL_WARNING("PNM encoder ignoring metadata - use a different codec");
    }
    encoded_image->icc = ppf.icc;
    encoded_image->bitstreams.clear();
    encoded_image->bitstreams.reserve(ppf.frames.size());
    for (const auto& frame : ppf.frames) {
      JXL_RETURN_IF_ERROR(VerifyPackedImage(frame.color, ppf.info));
      encoded_image->bitstreams.emplace_back();
      JXL_RETURN_IF_ERROR(
          EncodeFrame(ppf, frame, &encoded_image->bitstreams.back()));
    }
    for (size_t i = 0; i < ppf.extra_channels_info.size(); ++i) {
      const auto& ec_info = ppf.extra_channels_info[i].ec_info;
      encoded_image->extra_channel_bitstreams.emplace_back();
      auto& ec_bitstreams = encoded_image->extra_channel_bitstreams.back();
      for (const auto& frame : ppf.frames) {
        ec_bitstreams.emplace_back();
        JXL_RETURN_IF_ERROR(EncodeExtraChannel(frame.extra_channels[i],
                                               ec_info.bits_per_sample,
                                               &ec_bitstreams.back()));
      }
    }
    return true;
  }

 protected:
  virtual Status EncodeFrame(const PackedPixelFile& ppf,
                             const PackedFrame& frame,
                             std::vector<uint8_t>* bytes) const = 0;
  virtual Status EncodeExtraChannel(const PackedImage& image,
                                    size_t bits_per_sample,
                                    std::vector<uint8_t>* bytes) const = 0;
};

class PPMEncoder : public PNMEncoder {
 public:
  std::vector<JxlPixelFormat> AcceptedFormats() const override {
    return {JxlPixelFormat{3, JXL_TYPE_UINT8, JXL_BIG_ENDIAN, 0},
            JxlPixelFormat{3, JXL_TYPE_UINT16, JXL_BIG_ENDIAN, 0}};
  }
  Status EncodeFrame(const PackedPixelFile& ppf, const PackedFrame& frame,
                     std::vector<uint8_t>* bytes) const override {
    return EncodeImage(frame.color, ppf.info.bits_per_sample, bytes);
  }
  Status EncodeExtraChannel(const PackedImage& image, size_t bits_per_sample,
                            std::vector<uint8_t>* bytes) const override {
    return EncodeImage(image, bits_per_sample, bytes);
  }

 private:
  Status EncodeImage(const PackedImage& image, size_t bits_per_sample,
                     std::vector<uint8_t>* bytes) const {
    uint32_t maxval = (1u << bits_per_sample) - 1;
    char type = image.format.num_channels == 1 ? '5' : '6';
    char header[kMaxHeaderSize];
    size_t header_size =
        snprintf(header, kMaxHeaderSize, "P%c\n%" PRIuS " %" PRIuS "\n%u\n",
                 type, image.xsize, image.ysize, maxval);
    JXL_RETURN_IF_ERROR(header_size < kMaxHeaderSize);
    bytes->resize(header_size + image.pixels_size);
    memcpy(bytes->data(), header, header_size);
    memcpy(bytes->data() + header_size,
           reinterpret_cast<uint8_t*>(image.pixels()), image.pixels_size);
    return true;
  }
};

class PGMEncoder : public PPMEncoder {
 public:
  std::vector<JxlPixelFormat> AcceptedFormats() const override {
    return {JxlPixelFormat{1, JXL_TYPE_UINT8, JXL_BIG_ENDIAN, 0},
            JxlPixelFormat{1, JXL_TYPE_UINT16, JXL_BIG_ENDIAN, 0}};
  }
};

class PFMEncoder : public PNMEncoder {
 public:
  std::vector<JxlPixelFormat> AcceptedFormats() const override {
    std::vector<JxlPixelFormat> formats;
    for (const uint32_t num_channels : {1, 3}) {
      for (JxlEndianness endianness : {JXL_BIG_ENDIAN, JXL_LITTLE_ENDIAN}) {
        formats.push_back(JxlPixelFormat{/*num_channels=*/num_channels,
                                         /*data_type=*/JXL_TYPE_FLOAT,
                                         /*endianness=*/endianness,
                                         /*align=*/0});
      }
    }
    return formats;
  }
  Status EncodeFrame(const PackedPixelFile& ppf, const PackedFrame& frame,
                     std::vector<uint8_t>* bytes) const override {
    return EncodeImage(frame.color, bytes);
  }
  Status EncodeExtraChannel(const PackedImage& image, size_t bits_per_sample,
                            std::vector<uint8_t>* bytes) const override {
    return EncodeImage(image, bytes);
  }

 private:
  Status EncodeImage(const PackedImage& image,
                     std::vector<uint8_t>* bytes) const {
    char type = image.format.num_channels == 1 ? 'f' : 'F';
    double scale = image.format.endianness == JXL_LITTLE_ENDIAN ? -1.0 : 1.0;
    char header[kMaxHeaderSize];
    size_t header_size =
        snprintf(header, kMaxHeaderSize, "P%c\n%" PRIuS " %" PRIuS "\n%.1f\n",
                 type, image.xsize, image.ysize, scale);
    JXL_RETURN_IF_ERROR(header_size < kMaxHeaderSize);
    bytes->resize(header_size + image.pixels_size);
    memcpy(bytes->data(), header, header_size);
    const uint8_t* in = reinterpret_cast<const uint8_t*>(image.pixels());
    uint8_t* out = bytes->data() + header_size;
    for (size_t y = 0; y < image.ysize; ++y) {
      size_t y_out = image.ysize - 1 - y;
      const uint8_t* row_in = &in[y * image.stride];
      uint8_t* row_out = &out[y_out * image.stride];
      memcpy(row_out, row_in, image.stride);
    }
    return true;
  }
};

class PAMEncoder : public PNMEncoder {
 public:
  std::vector<JxlPixelFormat> AcceptedFormats() const override {
    std::vector<JxlPixelFormat> formats;
    for (const uint32_t num_channels : {1, 2, 3, 4}) {
      for (const JxlDataType data_type : {JXL_TYPE_UINT8, JXL_TYPE_UINT16}) {
        formats.push_back(JxlPixelFormat{/*num_channels=*/num_channels,
                                         /*data_type=*/data_type,
                                         /*endianness=*/JXL_BIG_ENDIAN,
                                         /*align=*/0});
      }
    }
    return formats;
  }
  Status EncodeFrame(const PackedPixelFile& ppf, const PackedFrame& frame,
                     std::vector<uint8_t>* bytes) const override {
    const PackedImage& color = frame.color;
    const auto& ec_info = ppf.extra_channels_info;
    JXL_RETURN_IF_ERROR(frame.extra_channels.size() == ec_info.size());
    for (const auto& ec : frame.extra_channels) {
      if (ec.xsize != color.xsize || ec.ysize != color.ysize) {
        return JXL_FAILURE("Extra channel and color size mismatch.");
      }
      if (ec.format.data_type != color.format.data_type ||
          ec.format.endianness != color.format.endianness) {
        return JXL_FAILURE("Extra channel and color format mismatch.");
      }
    }
    if (ppf.info.bits_per_sample != ppf.info.alpha_bits) {
      return JXL_FAILURE("Alpha bit depth does not match image bit depth");
    }
    for (const auto& it : ec_info) {
      if (it.ec_info.bits_per_sample != ppf.info.bits_per_sample) {
        return JXL_FAILURE(
            "Extra channel bit depth does not match image bit depth");
      }
    }
    const char* kColorTypes[4] = {"GRAYSCALE", "GRAYSCALE_ALPHA", "RGB",
                                  "RGB_ALPHA"};
    uint32_t maxval = (1u << ppf.info.bits_per_sample) - 1;
    uint32_t depth = color.format.num_channels + ec_info.size();
    char header[kMaxHeaderSize];
    size_t pos = 0;
    pos += snprintf(header + pos, kMaxHeaderSize - pos,
                    "P7\nWIDTH %" PRIuS "\nHEIGHT %" PRIuS
                    "\nDEPTH %u\n"
                    "MAXVAL %u\nTUPLTYPE %s\n",
                    color.xsize, color.ysize, depth, maxval,
                    kColorTypes[color.format.num_channels - 1]);
    JXL_RETURN_IF_ERROR(pos < kMaxHeaderSize);
    for (const auto& info : ec_info) {
      pos += snprintf(header + pos, kMaxHeaderSize - pos, "TUPLTYPE %s\n",
                      ExtraChannelTypeName(info.ec_info.type).c_str());
      JXL_RETURN_IF_ERROR(pos < kMaxHeaderSize);
    }
    pos += snprintf(header + pos, kMaxHeaderSize - pos, "ENDHDR\n");
    JXL_RETURN_IF_ERROR(pos < kMaxHeaderSize);
    size_t total_size = color.pixels_size;
    for (const auto& ec : frame.extra_channels) {
      total_size += ec.pixels_size;
    }
    bytes->resize(pos + total_size);
    memcpy(bytes->data(), header, pos);
    // If we have no extra channels, just copy color pixel data over.
    if (frame.extra_channels.empty()) {
      memcpy(bytes->data() + pos, reinterpret_cast<uint8_t*>(color.pixels()),
             color.pixels_size);
      return true;
    }
    // Interleave color and extra channels.
    const uint8_t* in = reinterpret_cast<const uint8_t*>(color.pixels());
    std::vector<const uint8_t*> ec_in(frame.extra_channels.size());
    for (size_t i = 0; i < frame.extra_channels.size(); ++i) {
      ec_in[i] =
          reinterpret_cast<const uint8_t*>(frame.extra_channels[i].pixels());
    }
    uint8_t* out = bytes->data() + pos;
    size_t pwidth = PackedImage::BitsPerChannel(color.format.data_type) / 8;
    for (size_t y = 0; y < color.ysize; ++y) {
      for (size_t x = 0; x < color.xsize; ++x) {
        memcpy(out, in, color.pixel_stride());
        out += color.pixel_stride();
        in += color.pixel_stride();
        for (auto& p : ec_in) {
          memcpy(out, p, pwidth);
          out += pwidth;
          p += pwidth;
        }
      }
    }
    return true;
  }
  Status EncodeExtraChannel(const PackedImage& image, size_t bits_per_sample,
                            std::vector<uint8_t>* bytes) const override {
    return true;
  }

 private:
  static std::string ExtraChannelTypeName(JxlExtraChannelType type) {
    switch (type) {
      case JXL_CHANNEL_ALPHA:
        return std::string("Alpha");
      case JXL_CHANNEL_DEPTH:
        return std::string("Depth");
      case JXL_CHANNEL_SPOT_COLOR:
        return std::string("SpotColor");
      case JXL_CHANNEL_SELECTION_MASK:
        return std::string("SelectionMask");
      case JXL_CHANNEL_BLACK:
        return std::string("Black");
      case JXL_CHANNEL_CFA:
        return std::string("CFA");
      case JXL_CHANNEL_THERMAL:
        return std::string("Thermal");
      default:
        return std::string("UNKNOWN");
    }
  }
};

}  // namespace

std::unique_ptr<Encoder> GetPPMEncoder() {
  return jxl::make_unique<PPMEncoder>();
}

std::unique_ptr<Encoder> GetPFMEncoder() {
  return jxl::make_unique<PFMEncoder>();
}

std::unique_ptr<Encoder> GetPGMEncoder() {
  return jxl::make_unique<PGMEncoder>();
}

std::unique_ptr<Encoder> GetPAMEncoder() {
  return jxl::make_unique<PAMEncoder>();
}

}  // namespace extras
}  // namespace jxl
