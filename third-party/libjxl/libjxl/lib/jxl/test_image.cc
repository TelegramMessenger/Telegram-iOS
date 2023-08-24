// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "lib/jxl/test_image.h"

#include <jxl/encode.h>

#include <algorithm>
#include <cstring>
#include <utility>

#include "lib/extras/dec/color_description.h"
#include "lib/extras/dec/color_hints.h"
#include "lib/extras/dec/decode.h"
#include "lib/jxl/base/byte_order.h"
#include "lib/jxl/base/random.h"
#include "lib/jxl/base/span.h"
#include "lib/jxl/base/status.h"
#include "lib/jxl/color_encoding_internal.h"

namespace jxl {
namespace test {

namespace {

void StoreValue(float val, size_t bits_per_sample, JxlPixelFormat format,
                uint8_t** out) {
  const float mul = (1u << bits_per_sample) - 1;
  if (format.data_type == JXL_TYPE_UINT8) {
    **out = val * mul;
  } else if (format.data_type == JXL_TYPE_UINT16) {
    uint16_t uval = val * mul;
    if (SwapEndianness(format.endianness)) {
      uval = JXL_BSWAP16(uval);
    }
    memcpy(*out, &uval, 2);
  } else if (format.data_type == JXL_TYPE_FLOAT) {
    // TODO(szabadka) Add support for custom bits / exponent bits floats.
    if (SwapEndianness(format.endianness)) {
      val = BSwapFloat(val);
    }
    memcpy(*out, &val, 4);
  } else {
    // TODO(szabadka) Add support for FLOAT16.
  }
  *out += extras::PackedImage::BitsPerChannel(format.data_type) / 8;
}

void FillPackedImage(size_t bits_per_sample, uint16_t seed,
                     extras::PackedImage* image) {
  const size_t xsize = image->xsize;
  const size_t ysize = image->ysize;
  const JxlPixelFormat format = image->format;

  // Cause more significant image difference for successive seeds.
  Rng generator(seed);

  // Returns random integer in interval [0, max_value)
  auto rngu = [&generator](size_t max_value) -> size_t {
    return generator.UniformU(0, max_value);
  };

  // Returns random float in interval [0.0, max_value)
  auto rngf = [&generator](float max_value) {
    return generator.UniformF(0.0f, max_value);
  };

  // Dark background gradient color
  float r0 = rngf(0.5f);
  float g0 = rngf(0.5f);
  float b0 = rngf(0.5f);
  float a0 = rngf(0.5f);
  float r1 = rngf(0.5f);
  float g1 = rngf(0.5f);
  float b1 = rngf(0.5f);
  float a1 = rngf(0.5f);

  // Circle with different color
  size_t circle_x = rngu(xsize);
  size_t circle_y = rngu(ysize);
  size_t circle_r = rngu(std::min(xsize, ysize));

  // Rectangle with random noise
  size_t rect_x0 = rngu(xsize);
  size_t rect_y0 = rngu(ysize);
  size_t rect_x1 = rngu(xsize);
  size_t rect_y1 = rngu(ysize);
  if (rect_x1 < rect_x0) std::swap(rect_x0, rect_y1);
  if (rect_y1 < rect_y0) std::swap(rect_y0, rect_y1);

  // Create pixel content to test, actual content does not matter as long as it
  // can be compared after roundtrip.
  uint8_t* out = reinterpret_cast<uint8_t*>(image->pixels());
  const float imul16 = 1.0f / 65536.0f;
  for (size_t y = 0; y < ysize; y++) {
    for (size_t x = 0; x < xsize; x++) {
      float r = r0 * (ysize - y - 1) / ysize + r1 * y / ysize;
      float g = g0 * (ysize - y - 1) / ysize + g1 * y / ysize;
      float b = b0 * (ysize - y - 1) / ysize + b1 * y / ysize;
      float a = a0 * (ysize - y - 1) / ysize + a1 * y / ysize;
      // put some shape in there for visual debugging
      if ((x - circle_x) * (x - circle_x) + (y - circle_y) * (y - circle_y) <
          circle_r * circle_r) {
        r = std::min(1.0f, ((65535 - x * y) ^ seed) * imul16);
        g = std::min(1.0f, ((x << 8) + y + seed) * imul16);
        b = std::min(1.0f, ((y << 8) + x * seed) * imul16);
        a = std::min(1.0f, (32768 + x * 256 - y) * imul16);
      } else if (x > rect_x0 && x < rect_x1 && y > rect_y0 && y < rect_y1) {
        r = rngf(1.0f);
        g = rngf(1.0f);
        b = rngf(1.0f);
        a = rngf(1.0f);
      }
      if (format.num_channels == 1) {
        StoreValue(g, bits_per_sample, format, &out);
      } else if (format.num_channels == 2) {
        StoreValue(g, bits_per_sample, format, &out);
        StoreValue(a, bits_per_sample, format, &out);
      } else if (format.num_channels == 3) {
        StoreValue(r, bits_per_sample, format, &out);
        StoreValue(g, bits_per_sample, format, &out);
        StoreValue(b, bits_per_sample, format, &out);
      } else if (format.num_channels == 4) {
        StoreValue(r, bits_per_sample, format, &out);
        StoreValue(g, bits_per_sample, format, &out);
        StoreValue(b, bits_per_sample, format, &out);
        StoreValue(a, bits_per_sample, format, &out);
      }
    }
  }
}

}  // namespace

std::vector<uint8_t> GetSomeTestImage(size_t xsize, size_t ysize,
                                      size_t num_channels, uint16_t seed) {
  // Cause more significant image difference for successive seeds.
  Rng generator(seed);

  // Returns random integer in interval [0, max_value)
  auto rng = [&generator](size_t max_value) -> size_t {
    return generator.UniformU(0, max_value);
  };

  // Dark background gradient color
  uint16_t r0 = rng(32768);
  uint16_t g0 = rng(32768);
  uint16_t b0 = rng(32768);
  uint16_t a0 = rng(32768);
  uint16_t r1 = rng(32768);
  uint16_t g1 = rng(32768);
  uint16_t b1 = rng(32768);
  uint16_t a1 = rng(32768);

  // Circle with different color
  size_t circle_x = rng(xsize);
  size_t circle_y = rng(ysize);
  size_t circle_r = rng(std::min(xsize, ysize));

  // Rectangle with random noise
  size_t rect_x0 = rng(xsize);
  size_t rect_y0 = rng(ysize);
  size_t rect_x1 = rng(xsize);
  size_t rect_y1 = rng(ysize);
  if (rect_x1 < rect_x0) std::swap(rect_x0, rect_y1);
  if (rect_y1 < rect_y0) std::swap(rect_y0, rect_y1);

  size_t num_pixels = xsize * ysize;
  // 16 bits per channel, big endian, 4 channels
  std::vector<uint8_t> pixels(num_pixels * num_channels * 2);
  // Create pixel content to test, actual content does not matter as long as it
  // can be compared after roundtrip.
  for (size_t y = 0; y < ysize; y++) {
    for (size_t x = 0; x < xsize; x++) {
      uint16_t r = r0 * (ysize - y - 1) / ysize + r1 * y / ysize;
      uint16_t g = g0 * (ysize - y - 1) / ysize + g1 * y / ysize;
      uint16_t b = b0 * (ysize - y - 1) / ysize + b1 * y / ysize;
      uint16_t a = a0 * (ysize - y - 1) / ysize + a1 * y / ysize;
      // put some shape in there for visual debugging
      if ((x - circle_x) * (x - circle_x) + (y - circle_y) * (y - circle_y) <
          circle_r * circle_r) {
        r = (65535 - x * y) ^ seed;
        g = (x << 8) + y + seed;
        b = (y << 8) + x * seed;
        a = 32768 + x * 256 - y;
      } else if (x > rect_x0 && x < rect_x1 && y > rect_y0 && y < rect_y1) {
        r = rng(65536);
        g = rng(65536);
        b = rng(65536);
        a = rng(65536);
      }
      size_t i = (y * xsize + x) * 2 * num_channels;
      pixels[i + 0] = (r >> 8);
      pixels[i + 1] = (r & 255);
      if (num_channels >= 2) {
        // This may store what is called 'g' in the alpha channel of a 2-channel
        // image, but that's ok since the content is arbitrary
        pixels[i + 2] = (g >> 8);
        pixels[i + 3] = (g & 255);
      }
      if (num_channels >= 3) {
        pixels[i + 4] = (b >> 8);
        pixels[i + 5] = (b & 255);
      }
      if (num_channels >= 4) {
        pixels[i + 6] = (a >> 8);
        pixels[i + 7] = (a & 255);
      }
    }
  }
  return pixels;
}

TestImage::TestImage() {
  SetChannels(3);
  SetAllBitDepths(8);
  SetColorEncoding("RGB_D65_SRG_Rel_SRG");
}

TestImage& TestImage::DecodeFromBytes(const PaddedBytes& bytes) {
  ColorEncoding c_enc;
  JXL_CHECK(
      ConvertExternalToInternalColorEncoding(ppf_.color_encoding, &c_enc));
  extras::ColorHints color_hints;
  color_hints.Add("color_space", Description(c_enc));
  JXL_CHECK(
      extras::DecodeBytes(Span<const uint8_t>(bytes), color_hints, &ppf_));
  return *this;
}

TestImage& TestImage::ClearMetadata() {
  ppf_.metadata = extras::PackedMetadata();
  return *this;
}

TestImage& TestImage::SetDimensions(size_t xsize, size_t ysize) {
  if (xsize <= ppf_.info.xsize && ysize <= ppf_.info.ysize) {
    for (auto& frame : ppf_.frames) {
      CropLayerInfo(xsize, ysize, &frame.frame_info.layer_info);
      CropImage(xsize, ysize, &frame.color);
      for (auto& ec : frame.extra_channels) {
        CropImage(xsize, ysize, &ec);
      }
    }
  } else {
    JXL_CHECK(ppf_.info.xsize == 0 && ppf_.info.ysize == 0);
  }
  ppf_.info.xsize = xsize;
  ppf_.info.ysize = ysize;
  return *this;
}

TestImage& TestImage::SetChannels(size_t num_channels) {
  JXL_CHECK(ppf_.frames.empty());
  JXL_CHECK(!ppf_.preview_frame);
  ppf_.info.num_color_channels = num_channels < 3 ? 1 : 3;
  ppf_.info.num_extra_channels = num_channels - ppf_.info.num_color_channels;
  if (ppf_.info.num_extra_channels > 0 && ppf_.info.alpha_bits == 0) {
    ppf_.info.alpha_bits = ppf_.info.bits_per_sample;
    ppf_.info.alpha_exponent_bits = ppf_.info.exponent_bits_per_sample;
  }
  ppf_.extra_channels_info.clear();
  for (size_t i = 1; i < ppf_.info.num_extra_channels; ++i) {
    extras::PackedExtraChannel ec;
    ec.index = i;
    JxlEncoderInitExtraChannelInfo(JXL_CHANNEL_ALPHA, &ec.ec_info);
    if (ec.ec_info.bits_per_sample == 0) {
      ec.ec_info.bits_per_sample = ppf_.info.bits_per_sample;
      ec.ec_info.exponent_bits_per_sample = ppf_.info.exponent_bits_per_sample;
    }
    ppf_.extra_channels_info.emplace_back(std::move(ec));
  }
  format_.num_channels = std::min(static_cast<size_t>(4), num_channels);
  if (ppf_.info.num_color_channels == 1 &&
      ppf_.color_encoding.color_space != JXL_COLOR_SPACE_GRAY) {
    SetColorEncoding("Gra_D65_Rel_SRG");
  }
  return *this;
}

// Sets the same bit depth on color, alpha and all extra channels.
TestImage& TestImage::SetAllBitDepths(uint32_t bits_per_sample,
                                      uint32_t exponent_bits_per_sample) {
  ppf_.info.bits_per_sample = bits_per_sample;
  ppf_.info.exponent_bits_per_sample = exponent_bits_per_sample;
  if (ppf_.info.num_extra_channels > 0) {
    ppf_.info.alpha_bits = bits_per_sample;
    ppf_.info.alpha_exponent_bits = exponent_bits_per_sample;
  }
  for (size_t i = 0; i < ppf_.extra_channels_info.size(); ++i) {
    extras::PackedExtraChannel& ec = ppf_.extra_channels_info[i];
    ec.ec_info.bits_per_sample = bits_per_sample;
    ec.ec_info.exponent_bits_per_sample = exponent_bits_per_sample;
  }
  format_.data_type = DefaultDataType(ppf_.info);
  return *this;
}

TestImage& TestImage::SetDataType(JxlDataType data_type) {
  format_.data_type = data_type;
  return *this;
}

TestImage& TestImage::SetEndianness(JxlEndianness endianness) {
  format_.endianness = endianness;
  return *this;
}

TestImage& TestImage::SetColorEncoding(const std::string& description) {
  JXL_CHECK(ParseDescription(description, &ppf_.color_encoding));
  ColorEncoding c_enc;
  JXL_CHECK(
      ConvertExternalToInternalColorEncoding(ppf_.color_encoding, &c_enc));
  JXL_CHECK(c_enc.CreateICC());
  PaddedBytes icc = c_enc.ICC();
  ppf_.icc.assign(icc.begin(), icc.end());
  return *this;
}

TestImage& TestImage::CoalesceGIFAnimationWithAlpha() {
  extras::PackedFrame canvas = ppf_.frames[0].Copy();
  JXL_CHECK(canvas.color.format.num_channels == 3);
  JXL_CHECK(canvas.color.format.data_type == JXL_TYPE_UINT8);
  JXL_CHECK(canvas.extra_channels.size() == 1);
  for (size_t i = 1; i < ppf_.frames.size(); i++) {
    const extras::PackedFrame& frame = ppf_.frames[i];
    JXL_CHECK(frame.extra_channels.size() == 1);
    const JxlLayerInfo& layer_info = frame.frame_info.layer_info;
    extras::PackedFrame rendered = canvas.Copy();
    uint8_t* pixels_rendered =
        reinterpret_cast<uint8_t*>(rendered.color.pixels());
    const uint8_t* pixels_frame =
        reinterpret_cast<const uint8_t*>(frame.color.pixels());
    uint8_t* alpha_rendered =
        reinterpret_cast<uint8_t*>(rendered.extra_channels[0].pixels());
    const uint8_t* alpha_frame =
        reinterpret_cast<const uint8_t*>(frame.extra_channels[0].pixels());
    for (size_t y = 0; y < frame.color.ysize; y++) {
      for (size_t x = 0; x < frame.color.xsize; x++) {
        size_t idx_frame = y * frame.color.xsize + x;
        size_t idx_rendered = ((layer_info.crop_y0 + y) * rendered.color.xsize +
                               (layer_info.crop_x0 + x));
        if (alpha_frame[idx_frame] != 0) {
          memcpy(&pixels_rendered[idx_rendered * 3],
                 &pixels_frame[idx_frame * 3], 3);
          alpha_rendered[idx_rendered] = alpha_frame[idx_frame];
        }
      }
    }
    if (layer_info.save_as_reference != 0) {
      canvas = rendered.Copy();
    }
    ppf_.frames[i] = std::move(rendered);
  }
  return *this;
}

TestImage::Frame::Frame(TestImage* parent, bool is_preview, size_t index)
    : parent_(parent), is_preview_(is_preview), index_(index) {}

void TestImage::Frame::ZeroFill() {
  memset(frame().color.pixels(), 0, frame().color.pixels_size);
  for (auto& ec : frame().extra_channels) {
    memset(ec.pixels(), 0, ec.pixels_size);
  }
}

void TestImage::Frame::RandomFill(uint16_t seed) {
  FillPackedImage(ppf().info.bits_per_sample, seed, &frame().color);
  for (size_t i = 0; i < ppf().extra_channels_info.size(); ++i) {
    FillPackedImage(ppf().extra_channels_info[i].ec_info.bits_per_sample,
                    seed + 1 + i, &frame().extra_channels[i]);
  }
}

void TestImage::Frame::SetValue(size_t y, size_t x, size_t c, float val) {
  const extras::PackedImage& color = frame().color;
  JxlPixelFormat format = color.format;
  JXL_CHECK(y < ppf().info.ysize);
  JXL_CHECK(x < ppf().info.xsize);
  JXL_CHECK(c < format.num_channels);
  size_t pwidth = extras::PackedImage::BitsPerChannel(format.data_type) / 8;
  size_t idx = ((y * color.xsize + x) * format.num_channels + c) * pwidth;
  uint8_t* pixels = reinterpret_cast<uint8_t*>(frame().color.pixels());
  uint8_t* p = pixels + idx;
  StoreValue(val, ppf().info.bits_per_sample, frame().color.format, &p);
}

TestImage::Frame TestImage::AddFrame() {
  size_t index = ppf_.frames.size();
  extras::PackedFrame frame(ppf_.info.xsize, ppf_.info.ysize, format_);
  for (size_t i = 0; i < ppf_.extra_channels_info.size(); ++i) {
    JxlPixelFormat ec_format = {1, format_.data_type, format_.endianness, 0};
    extras::PackedImage image(ppf_.info.xsize, ppf_.info.ysize, ec_format);
    frame.extra_channels.emplace_back(std::move(image));
  }
  ppf_.frames.emplace_back(std::move(frame));
  return Frame(this, false, index);
}

TestImage::Frame TestImage::AddPreview(size_t xsize, size_t ysize) {
  extras::PackedFrame frame(xsize, ysize, format_);
  for (size_t i = 0; i < ppf_.extra_channels_info.size(); ++i) {
    JxlPixelFormat ec_format = {1, format_.data_type, format_.endianness, 0};
    extras::PackedImage image(xsize, ysize, ec_format);
    frame.extra_channels.emplace_back(std::move(image));
  }
  ppf_.preview_frame = make_unique<extras::PackedFrame>(std::move(frame));
  return Frame(this, true, 0);
}

void TestImage::CropLayerInfo(size_t xsize, size_t ysize, JxlLayerInfo* info) {
  if (info->crop_x0 < static_cast<ssize_t>(xsize)) {
    info->xsize = std::min<size_t>(info->xsize, xsize - info->crop_x0);
  } else {
    info->xsize = 0;
  }
  if (info->crop_y0 < static_cast<ssize_t>(ysize)) {
    info->ysize = std::min<size_t>(info->ysize, ysize - info->crop_y0);
  } else {
    info->ysize = 0;
  }
}

void TestImage::CropImage(size_t xsize, size_t ysize,
                          extras::PackedImage* image) {
  size_t new_stride = (image->stride / image->xsize) * xsize;
  uint8_t* buf = reinterpret_cast<uint8_t*>(image->pixels());
  for (size_t y = 0; y < ysize; ++y) {
    memmove(&buf[y * new_stride], &buf[y * image->stride], new_stride);
  }
  image->xsize = xsize;
  image->ysize = ysize;
  image->stride = new_stride;
  image->pixels_size = ysize * new_stride;
}

JxlDataType TestImage::DefaultDataType(const JxlBasicInfo& info) {
  if (info.bits_per_sample == 16 && info.exponent_bits_per_sample == 5) {
    return JXL_TYPE_FLOAT16;
  } else if (info.exponent_bits_per_sample > 0 || info.bits_per_sample > 16) {
    return JXL_TYPE_FLOAT;
  } else if (info.bits_per_sample > 8) {
    return JXL_TYPE_UINT16;
  } else {
    return JXL_TYPE_UINT8;
  }
}

}  // namespace test
}  // namespace jxl
