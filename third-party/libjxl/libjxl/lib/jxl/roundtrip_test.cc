// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include <jxl/codestream_header.h>
#include <jxl/decode.h>
#include <jxl/decode_cxx.h>
#include <jxl/encode.h>
#include <jxl/encode_cxx.h>
#include <jxl/types.h>

#include <cmath>  // std::abs
#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <vector>

#include "lib/extras/codec.h"
#include "lib/jxl/dec_external_image.h"
#include "lib/jxl/enc_butteraugli_comparator.h"
#include "lib/jxl/enc_color_management.h"
#include "lib/jxl/enc_comparator.h"
#include "lib/jxl/enc_external_image.h"
#include "lib/jxl/encode_internal.h"
#include "lib/jxl/icc_codec.h"
#include "lib/jxl/image_test_utils.h"
#include "lib/jxl/test_utils.h"
#include "lib/jxl/testing.h"

namespace {

// Converts a test image to a CodecInOut.
// icc_profile can be empty to automatically deduce profile from the pixel
// format, or filled in to force this ICC profile
jxl::CodecInOut ConvertTestImage(const std::vector<uint8_t>& buf,
                                 const size_t xsize, const size_t ysize,
                                 const JxlPixelFormat& pixel_format,
                                 const jxl::PaddedBytes& icc_profile) {
  jxl::CodecInOut io;
  io.SetSize(xsize, ysize);

  bool is_gray = pixel_format.num_channels < 3;
  bool has_alpha =
      pixel_format.num_channels == 2 || pixel_format.num_channels == 4;

  io.metadata.m.color_encoding.SetColorSpace(is_gray ? jxl::ColorSpace::kGray
                                                     : jxl::ColorSpace::kRGB);
  if (has_alpha) {
    // Note: alpha > 16 not yet supported by the C++ codec
    switch (pixel_format.data_type) {
      case JXL_TYPE_UINT8:
        io.metadata.m.SetAlphaBits(8);
        break;
      case JXL_TYPE_UINT16:
      case JXL_TYPE_FLOAT:
      case JXL_TYPE_FLOAT16:
        io.metadata.m.SetAlphaBits(16);
        break;
      default:
        ADD_FAILURE() << "Roundtrip tests for data type "
                      << pixel_format.data_type << " not yet implemented.";
    }
  }
  size_t bitdepth = 0;
  switch (pixel_format.data_type) {
    case JXL_TYPE_FLOAT:
      bitdepth = 32;
      io.metadata.m.SetFloat32Samples();
      break;
    case JXL_TYPE_FLOAT16:
      bitdepth = 16;
      io.metadata.m.SetFloat16Samples();
      break;
    case JXL_TYPE_UINT8:
      bitdepth = 8;
      io.metadata.m.SetUintSamples(8);
      break;
    case JXL_TYPE_UINT16:
      bitdepth = 16;
      io.metadata.m.SetUintSamples(16);
      break;
    default:
      ADD_FAILURE() << "Roundtrip tests for data type "
                    << pixel_format.data_type << " not yet implemented.";
  }
  jxl::ColorEncoding color_encoding;
  if (!icc_profile.empty()) {
    jxl::PaddedBytes icc_profile_copy(icc_profile);
    EXPECT_TRUE(
        color_encoding.SetICC(std::move(icc_profile_copy), &jxl::GetJxlCms()));
  } else if (pixel_format.data_type == JXL_TYPE_FLOAT) {
    color_encoding = jxl::ColorEncoding::LinearSRGB(is_gray);
  } else {
    color_encoding = jxl::ColorEncoding::SRGB(is_gray);
  }
  EXPECT_TRUE(
      ConvertFromExternal(jxl::Span<const uint8_t>(buf.data(), buf.size()),
                          xsize, ysize, color_encoding,
                          /*bits_per_sample=*/bitdepth, pixel_format,
                          /*pool=*/nullptr, &io.Main()));
  return io;
}

template <typename T>
T ConvertTestPixel(float val);

template <>
float ConvertTestPixel<float>(const float val) {
  return val;
}

template <>
uint16_t ConvertTestPixel<uint16_t>(const float val) {
  return (uint16_t)(val * UINT16_MAX);
}

template <>
uint8_t ConvertTestPixel<uint8_t>(const float val) {
  return (uint8_t)(val * UINT8_MAX);
}

// Returns a test image.
template <typename T>
std::vector<uint8_t> GetTestImage(const size_t xsize, const size_t ysize,
                                  const JxlPixelFormat& pixel_format) {
  std::vector<T> pixels(xsize * ysize * pixel_format.num_channels);
  for (size_t y = 0; y < ysize; y++) {
    for (size_t x = 0; x < xsize; x++) {
      for (size_t chan = 0; chan < pixel_format.num_channels; chan++) {
        float val;
        switch (chan % 4) {
          case 0:
            val = static_cast<float>(y) / static_cast<float>(ysize);
            break;
          case 1:
            val = static_cast<float>(x) / static_cast<float>(xsize);
            break;
          case 2:
            val = static_cast<float>(x + y) / static_cast<float>(xsize + ysize);
            break;
          case 3:
            val = static_cast<float>(x * y) / static_cast<float>(xsize * ysize);
            break;
        }
        pixels[(y * xsize + x) * pixel_format.num_channels + chan] =
            ConvertTestPixel<T>(val);
      }
    }
  }
  std::vector<uint8_t> bytes(pixels.size() * sizeof(T));
  memcpy(bytes.data(), pixels.data(), sizeof(T) * pixels.size());
  return bytes;
}

void EncodeWithEncoder(JxlEncoder* enc, std::vector<uint8_t>* compressed) {
  compressed->resize(64);
  uint8_t* next_out = compressed->data();
  size_t avail_out = compressed->size() - (next_out - compressed->data());
  JxlEncoderStatus process_result = JXL_ENC_NEED_MORE_OUTPUT;
  while (process_result == JXL_ENC_NEED_MORE_OUTPUT) {
    process_result = JxlEncoderProcessOutput(enc, &next_out, &avail_out);
    if (process_result == JXL_ENC_NEED_MORE_OUTPUT) {
      size_t offset = next_out - compressed->data();
      compressed->resize(compressed->size() * 2);
      next_out = compressed->data() + offset;
      avail_out = compressed->size() - offset;
    }
  }
  compressed->resize(next_out - compressed->data());
  EXPECT_EQ(JXL_ENC_SUCCESS, process_result);
}

// Generates some pixels using some dimensions and pixel_format,
// compresses them, and verifies that the decoded version is similar to the
// original pixels.
// TODO(firsching): change this to be a parameterized test, like in
// decode_test.cc
template <typename T>
void VerifyRoundtripCompression(
    const size_t xsize, const size_t ysize,
    const JxlPixelFormat& input_pixel_format,
    const JxlPixelFormat& output_pixel_format, const bool lossless,
    const bool use_container, const uint32_t resampling = 1,
    const bool already_downsampled = false,
    const std::vector<std::pair<JxlExtraChannelType, std::string>>&
        extra_channels = {}) {
  size_t orig_xsize = xsize;
  size_t orig_ysize = ysize;
  if (already_downsampled) {
    orig_xsize = jxl::DivCeil(xsize, resampling);
    orig_ysize = jxl::DivCeil(ysize, resampling);
  }

  JxlPixelFormat extra_channel_pixel_format = input_pixel_format;
  extra_channel_pixel_format.num_channels = 1;
  const std::vector<uint8_t> extra_channel_bytes =
      GetTestImage<T>(xsize, ysize, extra_channel_pixel_format);
  const std::vector<uint8_t> original_bytes =
      GetTestImage<T>(orig_xsize, orig_ysize, input_pixel_format);
  jxl::CodecInOut original_io = ConvertTestImage(
      original_bytes, orig_xsize, orig_ysize, input_pixel_format, {});

  JxlEncoder* enc = JxlEncoderCreate(nullptr);
  EXPECT_NE(nullptr, enc);
  EXPECT_EQ(JXL_ENC_SUCCESS, JxlEncoderSetCodestreamLevel(enc, 10));
  EXPECT_EQ(JXL_ENC_SUCCESS, JxlEncoderUseContainer(enc, use_container));
  JxlBasicInfo basic_info;
  jxl::test::JxlBasicInfoSetFromPixelFormat(&basic_info, &input_pixel_format);
  basic_info.xsize = xsize;
  basic_info.ysize = ysize;
  basic_info.uses_original_profile = lossless;
  uint32_t num_channels = input_pixel_format.num_channels;
  size_t has_interleaved_alpha = num_channels == 2 || num_channels == 4;
  JxlPixelFormat output_pixel_format_with_extra_channel_alpha =
      output_pixel_format;

  // In the case where we have an alpha channel, but it is provided as an extra
  // channel and not interleaved, we do two things here:
  // 1. modify the original_io to have the correct alpha channel
  // 2. change the output_format_with_extra_alpha to have an alpha channel
  bool alpha_in_extra_channels_vector = false;
  for (const auto& extra_channel : extra_channels) {
    if (extra_channel.first == JXL_CHANNEL_ALPHA) {
      alpha_in_extra_channels_vector = true;
    }
  }
  if (alpha_in_extra_channels_vector && !has_interleaved_alpha) {
    jxl::ImageF alpha_channel(xsize, ysize);
    EXPECT_TRUE(jxl::ConvertFromExternal(
        jxl::Span<const uint8_t>(extra_channel_bytes.data(),
                                 extra_channel_bytes.size()),
        xsize, ysize, basic_info.bits_per_sample, extra_channel_pixel_format, 0,
        /*pool=*/nullptr, &alpha_channel));

    original_io.metadata.m.SetAlphaBits(basic_info.bits_per_sample);
    original_io.Main().SetAlpha(std::move(alpha_channel));
    output_pixel_format_with_extra_channel_alpha.num_channels++;
  }
  // Those are the num_extra_channels including a potential alpha channel.
  basic_info.num_extra_channels = extra_channels.size() + has_interleaved_alpha;
  EXPECT_EQ(JXL_ENC_SUCCESS, JxlEncoderSetBasicInfo(enc, &basic_info));
  EXPECT_EQ(enc->metadata.m.num_extra_channels,
            extra_channels.size() + has_interleaved_alpha);
  JxlColorEncoding color_encoding;
  if (input_pixel_format.data_type == JXL_TYPE_FLOAT) {
    JxlColorEncodingSetToLinearSRGB(
        &color_encoding,
        /*is_gray=*/input_pixel_format.num_channels < 3);
  } else {
    JxlColorEncodingSetToSRGB(&color_encoding,
                              /*is_gray=*/input_pixel_format.num_channels < 3);
  }

  std::vector<JxlExtraChannelInfo> channel_infos;
  for (const auto& extra_channel : extra_channels) {
    auto channel_type = extra_channel.first;
    JxlExtraChannelInfo channel_info;
    JxlEncoderInitExtraChannelInfo(channel_type, &channel_info);
    channel_info.bits_per_sample = (lossless ? basic_info.bits_per_sample : 8);
    channel_info.exponent_bits_per_sample =
        (lossless ? basic_info.exponent_bits_per_sample : 0);
    channel_infos.push_back(channel_info);
  }
  for (size_t index = 0; index < channel_infos.size(); index++) {
    EXPECT_EQ(JXL_ENC_SUCCESS,
              JxlEncoderSetExtraChannelInfo(enc, index + has_interleaved_alpha,
                                            &channel_infos[index]));
    std::string name = extra_channels[index].second;
    EXPECT_EQ(JXL_ENC_SUCCESS,
              JxlEncoderSetExtraChannelName(enc, index + has_interleaved_alpha,
                                            name.c_str(), name.length()));
  }
  EXPECT_EQ(JXL_ENC_SUCCESS, JxlEncoderSetColorEncoding(enc, &color_encoding));
  JxlEncoderFrameSettings* frame_settings =
      JxlEncoderFrameSettingsCreate(enc, nullptr);
  JxlEncoderSetFrameLossless(frame_settings, lossless);
  if (resampling > 1) {
    EXPECT_EQ(
        JXL_ENC_SUCCESS,
        JxlEncoderFrameSettingsSetOption(
            frame_settings, JXL_ENC_FRAME_SETTING_RESAMPLING, resampling));
    EXPECT_EQ(JXL_ENC_SUCCESS,
              JxlEncoderFrameSettingsSetOption(
                  frame_settings, JXL_ENC_FRAME_SETTING_ALREADY_DOWNSAMPLED,
                  already_downsampled));
  }
  EXPECT_EQ(JXL_ENC_SUCCESS,
            JxlEncoderAddImageFrame(frame_settings, &input_pixel_format,
                                    (void*)original_bytes.data(),
                                    original_bytes.size()));
  EXPECT_EQ(frame_settings->enc->input_queue.back()
                .frame->frame.extra_channels()
                .size(),
            has_interleaved_alpha + extra_channels.size());
  EXPECT_EQ(frame_settings->enc->input_queue.empty(), false);
  for (size_t index = 0; index < channel_infos.size(); index++) {
    EXPECT_EQ(JXL_ENC_SUCCESS,
              JxlEncoderSetExtraChannelBuffer(
                  frame_settings, &extra_channel_pixel_format,
                  (void*)extra_channel_bytes.data(), extra_channel_bytes.size(),
                  index + has_interleaved_alpha));
  }
  JxlEncoderCloseInput(enc);
  EXPECT_EQ(frame_settings->enc->input_queue.back()
                .frame->frame.extra_channels()
                .size(),
            has_interleaved_alpha + extra_channels.size());
  std::vector<uint8_t> compressed;
  EncodeWithEncoder(enc, &compressed);
  JxlEncoderDestroy(enc);

  JxlDecoder* dec = JxlDecoderCreate(nullptr);
  EXPECT_NE(nullptr, dec);

  const uint8_t* next_in = compressed.data();
  size_t avail_in = compressed.size();

  EXPECT_EQ(JXL_DEC_SUCCESS,
            JxlDecoderSubscribeEvents(dec, JXL_DEC_BASIC_INFO |
                                               JXL_DEC_COLOR_ENCODING |
                                               JXL_DEC_FULL_IMAGE));

  JxlDecoderSetInput(dec, next_in, avail_in);
  EXPECT_EQ(JXL_DEC_BASIC_INFO, JxlDecoderProcessInput(dec));
  size_t buffer_size;
  EXPECT_EQ(
      JXL_DEC_SUCCESS,
      JxlDecoderImageOutBufferSize(
          dec, &output_pixel_format_with_extra_channel_alpha, &buffer_size));
  if (&input_pixel_format == &output_pixel_format_with_extra_channel_alpha &&
      !already_downsampled) {
    EXPECT_EQ(buffer_size, original_bytes.size());
  }

  JxlBasicInfo info;
  EXPECT_EQ(JXL_DEC_SUCCESS, JxlDecoderGetBasicInfo(dec, &info));
  EXPECT_EQ(xsize, info.xsize);
  EXPECT_EQ(ysize, info.ysize);
  EXPECT_EQ(extra_channels.size() + has_interleaved_alpha,
            info.num_extra_channels);

  EXPECT_EQ(JXL_DEC_COLOR_ENCODING, JxlDecoderProcessInput(dec));

  size_t icc_profile_size;
  EXPECT_EQ(JXL_DEC_SUCCESS,
            JxlDecoderGetICCProfileSize(dec, JXL_COLOR_PROFILE_TARGET_DATA,
                                        &icc_profile_size));
  jxl::PaddedBytes icc_profile(icc_profile_size);
  EXPECT_EQ(JXL_DEC_SUCCESS, JxlDecoderGetColorAsICCProfile(
                                 dec, JXL_COLOR_PROFILE_TARGET_DATA,
                                 icc_profile.data(), icc_profile.size()));

  std::vector<uint8_t> decoded_bytes(buffer_size);

  EXPECT_EQ(JXL_DEC_NEED_IMAGE_OUT_BUFFER, JxlDecoderProcessInput(dec));

  EXPECT_EQ(JXL_DEC_SUCCESS,
            JxlDecoderSetImageOutBuffer(
                dec, &output_pixel_format_with_extra_channel_alpha,
                decoded_bytes.data(), decoded_bytes.size()));
  std::vector<std::vector<uint8_t>> extra_channel_decoded_bytes(
      info.num_extra_channels - has_interleaved_alpha);

  for (size_t index = has_interleaved_alpha; index < info.num_extra_channels;
       index++) {
    JxlExtraChannelInfo channel_info;
    EXPECT_EQ(JXL_DEC_SUCCESS,
              JxlDecoderGetExtraChannelInfo(dec, index, &channel_info));
    EXPECT_EQ(channel_info.type,
              extra_channels[index - has_interleaved_alpha].first);
    std::string input_name =
        extra_channels[index - has_interleaved_alpha].second;
    const size_t name_length = channel_info.name_length;
    EXPECT_EQ(input_name.size(), name_length);
    std::vector<char> output_name(name_length + 1);
    EXPECT_EQ(JXL_DEC_SUCCESS,
              JxlDecoderGetExtraChannelName(dec, index, output_name.data(),
                                            output_name.size()));
    EXPECT_EQ(0,
              memcmp(input_name.data(), output_name.data(), input_name.size()));
    size_t extra_buffer_size;
    EXPECT_EQ(JXL_DEC_SUCCESS,
              JxlDecoderExtraChannelBufferSize(dec, &output_pixel_format,
                                               &extra_buffer_size, index));
    std::vector<uint8_t> extra_decoded_bytes(extra_buffer_size);
    extra_channel_decoded_bytes[index - has_interleaved_alpha] =
        std::move(extra_decoded_bytes);
    EXPECT_EQ(
        JXL_DEC_SUCCESS,
        JxlDecoderSetExtraChannelBuffer(
            dec, &output_pixel_format,
            extra_channel_decoded_bytes[index - has_interleaved_alpha].data(),
            extra_channel_decoded_bytes[index - has_interleaved_alpha].size(),
            index));
  }
  EXPECT_EQ(JXL_DEC_FULL_IMAGE, JxlDecoderProcessInput(dec));
  // Check if there are no further errors after getting the full image, e.g.
  // check that the final codestream box is actually marked as last.
  EXPECT_EQ(JXL_DEC_SUCCESS, JxlDecoderProcessInput(dec));

  JxlDecoderDestroy(dec);

  jxl::CodecInOut decoded_io = ConvertTestImage(
      decoded_bytes, xsize, ysize, output_pixel_format_with_extra_channel_alpha,
      icc_profile);

  if (already_downsampled) {
    jxl::Image3F* color = decoded_io.Main().color();
    jxl::DownsampleImage(color, resampling);
    if (decoded_io.Main().HasAlpha()) {
      jxl::ImageF* alpha = decoded_io.Main().alpha();
      jxl::DownsampleImage(alpha, resampling);
    }
    decoded_io.SetSize(color->xsize(), color->ysize());
  }

  if (lossless && !already_downsampled) {
    JXL_EXPECT_OK(jxl::SamePixels(*original_io.Main().color(),
                                  *decoded_io.Main().color(), _));
  } else {
    jxl::ButteraugliParams ba;
    float butteraugli_score = ButteraugliDistance(
        original_io.frames, decoded_io.frames, ba, jxl::GetJxlCms(),
        /*distmap=*/nullptr, nullptr);
    EXPECT_LE(butteraugli_score, 2.0f);
  }
  JxlPixelFormat extra_channel_output_pixel_format = output_pixel_format;
  extra_channel_output_pixel_format.num_channels = 1;
  for (auto& extra_channel : extra_channel_decoded_bytes) {
    EXPECT_EQ(extra_channel.size(), extra_channel_bytes.size());
    if (lossless) {
      EXPECT_EQ(jxl::test::ComparePixels(extra_channel.data(),
                                         extra_channel_bytes.data(), xsize,
                                         ysize, extra_channel_pixel_format,
                                         extra_channel_output_pixel_format),
                0u);
      EXPECT_EQ(extra_channel, extra_channel_bytes);
    }
  }
}

}  // namespace

TEST(RoundtripTest, FloatFrameRoundtripTest) {
  std::vector<std::vector<std::pair<JxlExtraChannelType, std::string>>>
      extra_channels_cases = {{},
                              {{JXL_CHANNEL_ALPHA, "my extra alpha channel"}},
                              {{JXL_CHANNEL_CFA, "my cfa channel"}},
                              {{JXL_CHANNEL_DEPTH, "depth"},
                               {JXL_CHANNEL_SELECTION_MASK, "mask"},
                               {JXL_CHANNEL_BLACK, "black"},
                               {JXL_CHANNEL_CFA, "my cfa channel"},
                               {JXL_CHANNEL_OPTIONAL, "optional channel"}},
                              {{JXL_CHANNEL_DEPTH, "very deep"}}};
  for (int use_container = 0; use_container < 2; use_container++) {
    for (int lossless = 0; lossless < 2; lossless++) {
      for (uint32_t num_channels = 1; num_channels < 5; num_channels++) {
        for (auto& extra_channels : extra_channels_cases) {
          uint32_t has_alpha = static_cast<uint32_t>(num_channels % 2 == 0);
          uint32_t total_extra_channels = has_alpha + extra_channels.size();
          // There's no support (yet) for lossless extra float
          // channels, so we don't test it.
          if (total_extra_channels == 0 || !lossless) {
            JxlPixelFormat pixel_format = JxlPixelFormat{
                num_channels, JXL_TYPE_FLOAT, JXL_NATIVE_ENDIAN, 0};
            VerifyRoundtripCompression<float>(
                63, 129, pixel_format, pixel_format, (bool)lossless,
                (bool)use_container, 1, false, extra_channels);
          }
        }
      }
    }
  }
}

TEST(RoundtripTest, Uint16FrameRoundtripTest) {
  std::vector<std::vector<std::pair<JxlExtraChannelType, std::string>>>
      extra_channels_cases = {{},
                              {{JXL_CHANNEL_ALPHA, "my extra alpha channel"}},
                              {{JXL_CHANNEL_CFA, "my cfa channel"}},
                              {{JXL_CHANNEL_CFA, "my cfa channel"},
                               {JXL_CHANNEL_BLACK, "k_channel"}},
                              {{JXL_CHANNEL_DEPTH, "very deep"}}};
  for (int use_container = 0; use_container < 2; use_container++) {
    for (int lossless = 0; lossless < 2; lossless++) {
      for (uint32_t num_channels = 1; num_channels < 5; num_channels++) {
        for (auto& extra_channels : extra_channels_cases) {
          JxlPixelFormat pixel_format = JxlPixelFormat{
              num_channels, JXL_TYPE_UINT16, JXL_NATIVE_ENDIAN, 0};
          VerifyRoundtripCompression<uint16_t>(
              63, 129, pixel_format, pixel_format, (bool)lossless,
              (bool)use_container, 1, false, extra_channels);
        }
      }
    }
  }
}

TEST(RoundtripTest, Uint8FrameRoundtripTest) {
  std::vector<std::vector<std::pair<JxlExtraChannelType, std::string>>>
      extra_channels_cases = {{},
                              {{JXL_CHANNEL_THERMAL, "temperature"}},
                              {{JXL_CHANNEL_ALPHA, "my extra alpha channel"}},
                              {{JXL_CHANNEL_CFA, "my cfa channel"}},
                              {{JXL_CHANNEL_CFA, "my cfa channel"},
                               {JXL_CHANNEL_BLACK, "k_channel"}},
                              {{JXL_CHANNEL_DEPTH, "very deep"}}};
  for (int use_container = 0; use_container < 2; use_container++) {
    for (int lossless = 0; lossless < 2; lossless++) {
      for (uint32_t num_channels = 1; num_channels < 5; num_channels++) {
        for (auto& extra_channels : extra_channels_cases) {
          JxlPixelFormat pixel_format = JxlPixelFormat{
              num_channels, JXL_TYPE_UINT8, JXL_NATIVE_ENDIAN, 0};
          VerifyRoundtripCompression<uint8_t>(
              63, 129, pixel_format, pixel_format, (bool)lossless,
              (bool)use_container, 1, false, extra_channels);
        }
      }
    }
  }
}

TEST(RoundtripTest, TestNonlinearSrgbAsXybEncoded) {
  for (int use_container = 0; use_container < 2; use_container++) {
    for (uint32_t num_channels = 1; num_channels < 5; num_channels++) {
      JxlPixelFormat pixel_format_in =
          JxlPixelFormat{num_channels, JXL_TYPE_UINT8, JXL_NATIVE_ENDIAN, 0};
      JxlPixelFormat pixel_format_out =
          JxlPixelFormat{num_channels, JXL_TYPE_FLOAT, JXL_NATIVE_ENDIAN, 0};
      VerifyRoundtripCompression<uint8_t>(
          63, 129, pixel_format_in, pixel_format_out,
          /*lossless=*/false, (bool)use_container, {});
    }
  }
}

TEST(RoundtripTest, Resampling) {
  JxlPixelFormat pixel_format =
      JxlPixelFormat{3, JXL_TYPE_UINT8, JXL_NATIVE_ENDIAN, 0};
  VerifyRoundtripCompression<uint8_t>(63, 129, pixel_format, pixel_format,
                                      /*lossless=*/false,
                                      /*use_container=*/false, 2,
                                      /*already_downsampled=*/false);

  // TODO(lode): also make this work for odd sizes. This requires a fix in
  // enc_frame.cc to not set custom_size_or_origin to true due to even/odd
  // mismatch.
  VerifyRoundtripCompression<uint8_t>(64, 128, pixel_format, pixel_format,
                                      /*lossless=*/true,
                                      /*use_container=*/false, 2,
                                      /*already_downsampled=*/true);
}

TEST(RoundtripTest, ExtraBoxesTest) {
  JxlPixelFormat pixel_format =
      JxlPixelFormat{4, JXL_TYPE_FLOAT, JXL_NATIVE_ENDIAN, 0};
  const size_t xsize = 61;
  const size_t ysize = 71;

  const std::vector<uint8_t> original_bytes =
      GetTestImage<float>(xsize, ysize, pixel_format);
  jxl::CodecInOut original_io =
      ConvertTestImage(original_bytes, xsize, ysize, pixel_format, {});

  JxlEncoder* enc = JxlEncoderCreate(nullptr);
  EXPECT_NE(nullptr, enc);

  EXPECT_EQ(JXL_ENC_SUCCESS, JxlEncoderUseContainer(enc, true));
  JxlBasicInfo basic_info;
  jxl::test::JxlBasicInfoSetFromPixelFormat(&basic_info, &pixel_format);
  basic_info.xsize = xsize;
  basic_info.ysize = ysize;
  basic_info.uses_original_profile = false;
  EXPECT_EQ(JXL_ENC_SUCCESS, JxlEncoderSetCodestreamLevel(enc, 10));
  EXPECT_EQ(JXL_ENC_SUCCESS, JxlEncoderSetBasicInfo(enc, &basic_info));
  JxlColorEncoding color_encoding;
  if (pixel_format.data_type == JXL_TYPE_FLOAT) {
    JxlColorEncodingSetToLinearSRGB(&color_encoding,
                                    /*is_gray=*/pixel_format.num_channels < 3);
  } else {
    JxlColorEncodingSetToSRGB(&color_encoding,
                              /*is_gray=*/pixel_format.num_channels < 3);
  }
  EXPECT_EQ(JXL_ENC_SUCCESS, JxlEncoderSetColorEncoding(enc, &color_encoding));
  JxlEncoderFrameSettings* frame_settings =
      JxlEncoderFrameSettingsCreate(enc, nullptr);
  JxlEncoderSetFrameLossless(frame_settings, false);
  EXPECT_EQ(JXL_ENC_SUCCESS,
            JxlEncoderAddImageFrame(frame_settings, &pixel_format,
                                    (void*)original_bytes.data(),
                                    original_bytes.size()));
  JxlEncoderCloseInput(enc);

  std::vector<uint8_t> compressed;
  EncodeWithEncoder(enc, &compressed);
  JxlEncoderDestroy(enc);

  std::vector<uint8_t> extra_data(1023);
  jxl::AppendBoxHeader(jxl::MakeBoxType("crud"), extra_data.size(), false,
                       &compressed);
  compressed.insert(compressed.end(), extra_data.begin(), extra_data.end());

  JxlDecoder* dec = JxlDecoderCreate(nullptr);
  EXPECT_NE(nullptr, dec);

  const uint8_t* next_in = compressed.data();
  size_t avail_in = compressed.size();

  EXPECT_EQ(JXL_DEC_SUCCESS,
            JxlDecoderSubscribeEvents(dec, JXL_DEC_BASIC_INFO |
                                               JXL_DEC_COLOR_ENCODING |
                                               JXL_DEC_FULL_IMAGE));

  JxlDecoderSetInput(dec, next_in, avail_in);
  EXPECT_EQ(JXL_DEC_BASIC_INFO, JxlDecoderProcessInput(dec));
  size_t buffer_size;
  EXPECT_EQ(JXL_DEC_SUCCESS,
            JxlDecoderImageOutBufferSize(dec, &pixel_format, &buffer_size));
  EXPECT_EQ(buffer_size, original_bytes.size());

  JxlBasicInfo info;
  EXPECT_EQ(JXL_DEC_SUCCESS, JxlDecoderGetBasicInfo(dec, &info));
  EXPECT_EQ(xsize, info.xsize);
  EXPECT_EQ(ysize, info.ysize);

  EXPECT_EQ(JXL_DEC_COLOR_ENCODING, JxlDecoderProcessInput(dec));

  size_t icc_profile_size;
  EXPECT_EQ(JXL_DEC_SUCCESS,
            JxlDecoderGetICCProfileSize(dec, JXL_COLOR_PROFILE_TARGET_DATA,
                                        &icc_profile_size));
  jxl::PaddedBytes icc_profile(icc_profile_size);
  EXPECT_EQ(JXL_DEC_SUCCESS, JxlDecoderGetColorAsICCProfile(
                                 dec, JXL_COLOR_PROFILE_TARGET_DATA,
                                 icc_profile.data(), icc_profile.size()));

  std::vector<uint8_t> decoded_bytes(buffer_size);

  EXPECT_EQ(JXL_DEC_NEED_IMAGE_OUT_BUFFER, JxlDecoderProcessInput(dec));

  EXPECT_EQ(JXL_DEC_SUCCESS, JxlDecoderSetImageOutBuffer(dec, &pixel_format,
                                                         decoded_bytes.data(),
                                                         decoded_bytes.size()));

  EXPECT_EQ(JXL_DEC_FULL_IMAGE, JxlDecoderProcessInput(dec));

  JxlDecoderDestroy(dec);

  jxl::CodecInOut decoded_io =
      ConvertTestImage(decoded_bytes, xsize, ysize, pixel_format, icc_profile);

  jxl::ButteraugliParams ba;
  float butteraugli_score = ButteraugliDistance(
      original_io.frames, decoded_io.frames, ba, jxl::GetJxlCms(),
      /*distmap=*/nullptr, nullptr);
  EXPECT_LE(butteraugli_score, 2.0f);
}

static const unsigned char kEncodedTestProfile[] = {
    0x1f, 0x8b, 0x1,  0x13, 0x10, 0x0,  0x0,  0x0,  0x20, 0x4c, 0xcc, 0x3,
    0xe7, 0xa0, 0xa5, 0xa2, 0x90, 0xa4, 0x27, 0xe8, 0x79, 0x1d, 0xe3, 0x26,
    0x57, 0x54, 0xef, 0x0,  0xe8, 0x97, 0x2,  0xce, 0xa1, 0xd7, 0x85, 0x16,
    0xb4, 0x29, 0x94, 0x58, 0xf2, 0x56, 0xc0, 0x76, 0xea, 0x23, 0xec, 0x7c,
    0x73, 0x51, 0x41, 0x40, 0x23, 0x21, 0x95, 0x4,  0x75, 0x12, 0xc9, 0xcc,
    0x16, 0xbd, 0xb6, 0x99, 0xad, 0xf8, 0x75, 0x35, 0xb6, 0x42, 0xae, 0xae,
    0xae, 0x86, 0x56, 0xf8, 0xcc, 0x16, 0x30, 0xb3, 0x45, 0xad, 0xd,  0x40,
    0xd6, 0xd1, 0xd6, 0x99, 0x40, 0xbe, 0xe2, 0xdc, 0x31, 0x7,  0xa6, 0xb9,
    0x27, 0x92, 0x38, 0x0,  0x3,  0x5e, 0x2c, 0xbe, 0xe6, 0xfb, 0x19, 0xbf,
    0xf3, 0x6d, 0xbc, 0x4d, 0x64, 0xe5, 0xba, 0x76, 0xde, 0x31, 0x65, 0x66,
    0x14, 0xa6, 0x3a, 0xc5, 0x8f, 0xb1, 0xb4, 0xba, 0x1f, 0xb1, 0xb8, 0xd4,
    0x75, 0xba, 0x18, 0x86, 0x95, 0x3c, 0x26, 0xf6, 0x25, 0x62, 0x53, 0xfd,
    0x9c, 0x94, 0x76, 0xf6, 0x95, 0x2c, 0xb1, 0xfd, 0xdc, 0xc0, 0xe4, 0x3f,
    0xb3, 0xff, 0x67, 0xde, 0xd5, 0x94, 0xcc, 0xb0, 0x83, 0x2f, 0x28, 0x93,
    0x92, 0x3,  0xa1, 0x41, 0x64, 0x60, 0x62, 0x70, 0x80, 0x87, 0xaf, 0xe7,
    0x60, 0x4a, 0x20, 0x23, 0xb3, 0x11, 0x7,  0x38, 0x38, 0xd4, 0xa,  0x66,
    0xb5, 0x93, 0x41, 0x90, 0x19, 0x17, 0x18, 0x60, 0xa5, 0xb,  0x7a, 0x24,
    0xaa, 0x20, 0x81, 0xac, 0xa9, 0xa1, 0x70, 0xa6, 0x12, 0x8a, 0x4a, 0xa3,
    0xa0, 0xf9, 0x9a, 0x97, 0xe7, 0xa8, 0xac, 0x8,  0xa8, 0xc4, 0x2a, 0x86,
    0xa7, 0x69, 0x1e, 0x67, 0xe6, 0xbe, 0xa4, 0xd3, 0xff, 0x91, 0x61, 0xf6,
    0x8a, 0xe6, 0xb5, 0xb3, 0x61, 0x9f, 0x19, 0x17, 0x98, 0x27, 0x6b, 0xe9,
    0x8,  0x98, 0xe1, 0x21, 0x4a, 0x9,  0xb5, 0xd7, 0xca, 0xfa, 0x94, 0xd0,
    0x69, 0x1a, 0xeb, 0x52, 0x1,  0x4e, 0xf5, 0xf6, 0xdf, 0x7f, 0xe7, 0x29,
    0x70, 0xee, 0x4,  0xda, 0x2f, 0xa4, 0xff, 0xfe, 0xbb, 0x6f, 0xa8, 0xff,
    0xfe, 0xdb, 0xaf, 0x8,  0xf6, 0x72, 0xa1, 0x40, 0x5d, 0xf0, 0x2d, 0x8,
    0x82, 0x5b, 0x87, 0xbd, 0x10, 0x8,  0xe9, 0x7,  0xee, 0x4b, 0x80, 0xda,
    0x4a, 0x4,  0xc5, 0x5e, 0xa0, 0xb7, 0x1e, 0x60, 0xb0, 0x59, 0x76, 0x60,
    0xb,  0x2e, 0x19, 0x8a, 0x2e, 0x1c, 0xe6, 0x6,  0x20, 0xb8, 0x64, 0x18,
    0x2a, 0xcf, 0x51, 0x94, 0xd4, 0xee, 0xc3, 0xfe, 0x39, 0x74, 0xd4, 0x2b,
    0x48, 0xc9, 0x83, 0x4c, 0x9b, 0xd0, 0x4c, 0x35, 0x10, 0xe3, 0x9,  0xf7,
    0x72, 0xf0, 0x7a, 0xe,  0xbf, 0x7d, 0x36, 0x2e, 0x19, 0x7e, 0x3f, 0xc,
    0xf7, 0x93, 0xe7, 0xf4, 0x1d, 0x32, 0xc6, 0xb0, 0x89, 0xad, 0xe0, 0x28,
    0xc1, 0xa7, 0x59, 0xe3, 0x0,
};

TEST(RoundtripTest, TestICCProfile) {
  // JxlEncoderSetICCProfile parses the ICC profile, so a valid profile is
  // needed. The profile should be passed correctly through the roundtrip.
  jxl::BitReader reader(jxl::Span<const uint8_t>(kEncodedTestProfile,
                                                 sizeof(kEncodedTestProfile)));
  jxl::PaddedBytes icc;
  ASSERT_TRUE(ReadICC(&reader, &icc));
  ASSERT_TRUE(reader.Close());

  JxlPixelFormat format =
      JxlPixelFormat{3, JXL_TYPE_UINT8, JXL_NATIVE_ENDIAN, 0};

  size_t xsize = 25;
  size_t ysize = 37;
  const std::vector<uint8_t> original_bytes =
      GetTestImage<uint8_t>(xsize, ysize, format);

  JxlEncoder* enc = JxlEncoderCreate(nullptr);
  EXPECT_NE(nullptr, enc);

  JxlBasicInfo basic_info;
  jxl::test::JxlBasicInfoSetFromPixelFormat(&basic_info, &format);
  basic_info.xsize = xsize;
  basic_info.ysize = ysize;
  basic_info.uses_original_profile = JXL_TRUE;
  EXPECT_EQ(JXL_ENC_SUCCESS, JxlEncoderSetBasicInfo(enc, &basic_info));

  EXPECT_EQ(JXL_ENC_SUCCESS,
            JxlEncoderSetICCProfile(enc, icc.data(), icc.size()));
  JxlEncoderFrameSettings* frame_settings =
      JxlEncoderFrameSettingsCreate(enc, nullptr);
  EXPECT_EQ(JXL_ENC_SUCCESS,
            JxlEncoderAddImageFrame(frame_settings, &format,
                                    (void*)original_bytes.data(),
                                    original_bytes.size()));
  JxlEncoderCloseInput(enc);

  std::vector<uint8_t> compressed;
  EncodeWithEncoder(enc, &compressed);
  JxlEncoderDestroy(enc);

  JxlDecoder* dec = JxlDecoderCreate(nullptr);
  EXPECT_NE(nullptr, dec);

  const uint8_t* next_in = compressed.data();
  size_t avail_in = compressed.size();

  EXPECT_EQ(JXL_DEC_SUCCESS,
            JxlDecoderSubscribeEvents(dec, JXL_DEC_BASIC_INFO |
                                               JXL_DEC_COLOR_ENCODING |
                                               JXL_DEC_FULL_IMAGE));

  JxlDecoderSetInput(dec, next_in, avail_in);
  EXPECT_EQ(JXL_DEC_BASIC_INFO, JxlDecoderProcessInput(dec));
  size_t buffer_size;
  EXPECT_EQ(JXL_DEC_SUCCESS,
            JxlDecoderImageOutBufferSize(dec, &format, &buffer_size));
  EXPECT_EQ(buffer_size, original_bytes.size());

  JxlBasicInfo info;
  EXPECT_EQ(JXL_DEC_SUCCESS, JxlDecoderGetBasicInfo(dec, &info));
  EXPECT_EQ(xsize, info.xsize);
  EXPECT_EQ(ysize, info.ysize);

  EXPECT_EQ(JXL_DEC_COLOR_ENCODING, JxlDecoderProcessInput(dec));

  size_t dec_icc_size;
  EXPECT_EQ(JXL_DEC_SUCCESS,
            JxlDecoderGetICCProfileSize(dec, JXL_COLOR_PROFILE_TARGET_ORIGINAL,
                                        &dec_icc_size));
  EXPECT_EQ(icc.size(), dec_icc_size);
  jxl::PaddedBytes dec_icc(dec_icc_size);
  EXPECT_EQ(JXL_DEC_SUCCESS, JxlDecoderGetColorAsICCProfile(
                                 dec, JXL_COLOR_PROFILE_TARGET_ORIGINAL,
                                 dec_icc.data(), dec_icc.size()));

  std::vector<uint8_t> decoded_bytes(buffer_size);

  EXPECT_EQ(JXL_DEC_NEED_IMAGE_OUT_BUFFER, JxlDecoderProcessInput(dec));

  EXPECT_EQ(JXL_DEC_SUCCESS,
            JxlDecoderSetImageOutBuffer(dec, &format, decoded_bytes.data(),
                                        decoded_bytes.size()));

  EXPECT_EQ(JXL_DEC_FULL_IMAGE, JxlDecoderProcessInput(dec));

  EXPECT_EQ(icc, dec_icc);

  JxlDecoderDestroy(dec);
}

TEST(RoundtripTest, JXL_TRANSCODE_JPEG_TEST(TestJPEGReconstruction)) {
  TEST_LIBJPEG_SUPPORT();
  const std::string jpeg_path = "jxl/flower/flower.png.im_q85_420.jpg";
  const jxl::PaddedBytes orig = jxl::test::ReadTestData(jpeg_path);
  jxl::CodecInOut orig_io;
  ASSERT_TRUE(
      SetFromBytes(jxl::Span<const uint8_t>(orig), &orig_io, /*pool=*/nullptr));

  JxlEncoderPtr enc = JxlEncoderMake(nullptr);
  JxlEncoderFrameSettings* frame_settings =
      JxlEncoderFrameSettingsCreate(enc.get(), NULL);

  EXPECT_EQ(JXL_ENC_SUCCESS, JxlEncoderUseContainer(enc.get(), JXL_TRUE));
  EXPECT_EQ(JXL_ENC_SUCCESS, JxlEncoderStoreJPEGMetadata(enc.get(), JXL_TRUE));
  EXPECT_EQ(JXL_ENC_SUCCESS,
            JxlEncoderAddJPEGFrame(frame_settings, orig.data(), orig.size()));
  JxlEncoderCloseInput(enc.get());

  std::vector<uint8_t> compressed;
  EncodeWithEncoder(enc.get(), &compressed);

  JxlDecoderPtr dec = JxlDecoderMake(nullptr);
  EXPECT_EQ(JXL_DEC_SUCCESS,
            JxlDecoderSubscribeEvents(
                dec.get(), JXL_DEC_JPEG_RECONSTRUCTION | JXL_DEC_FULL_IMAGE));
  JxlDecoderSetInput(dec.get(), compressed.data(), compressed.size());
  EXPECT_EQ(JXL_DEC_JPEG_RECONSTRUCTION, JxlDecoderProcessInput(dec.get()));
  std::vector<uint8_t> reconstructed_buffer(128);
  EXPECT_EQ(JXL_DEC_SUCCESS,
            JxlDecoderSetJPEGBuffer(dec.get(), reconstructed_buffer.data(),
                                    reconstructed_buffer.size()));
  size_t used = 0;
  JxlDecoderStatus dec_process_result = JXL_DEC_JPEG_NEED_MORE_OUTPUT;
  while (dec_process_result == JXL_DEC_JPEG_NEED_MORE_OUTPUT) {
    used = reconstructed_buffer.size() - JxlDecoderReleaseJPEGBuffer(dec.get());
    reconstructed_buffer.resize(reconstructed_buffer.size() * 2);
    EXPECT_EQ(
        JXL_DEC_SUCCESS,
        JxlDecoderSetJPEGBuffer(dec.get(), reconstructed_buffer.data() + used,
                                reconstructed_buffer.size() - used));
    dec_process_result = JxlDecoderProcessInput(dec.get());
  }
  ASSERT_EQ(JXL_DEC_FULL_IMAGE, dec_process_result);
  used = reconstructed_buffer.size() - JxlDecoderReleaseJPEGBuffer(dec.get());
  ASSERT_EQ(used, orig.size());
  EXPECT_EQ(0, memcmp(reconstructed_buffer.data(), orig.data(), used));
}
