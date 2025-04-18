// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include <jxl/encode.h>
#include <jxl/encode_cxx.h>
#include <jxl/thread_parallel_runner.h>
#include <jxl/thread_parallel_runner_cxx.h>
#include <limits.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <algorithm>
#include <functional>
#include <hwy/targets.h>
#include <random>
#include <vector>

#include "lib/jxl/base/status.h"
#include "lib/jxl/test_image.h"

namespace {

#define TRY(expr)                                \
  do {                                           \
    if (JXL_ENC_SUCCESS != (expr)) return false; \
  } while (0)

struct FuzzSpec {
  size_t xsize;
  size_t ysize;
  struct OptionSpec {
    JxlEncoderFrameSettingId id;
    int32_t value;
  };
  std::vector<OptionSpec> options;
  bool is_jpeg = false;
  bool lossless = false;
  bool have_alpha = false;
  bool premultiply = false;
  bool orig_profile = true;
  uint16_t pixels_seed = 0;
  uint16_t alpha_seed = 0;
  size_t bit_depth = 8;
  size_t alpha_bit_depth = 8;
  int32_t codestream_level = -1;
  std::vector<uint8_t> icc;
  JxlColorEncoding color_encoding;
  size_t num_frames = 1;
  size_t output_buffer_size = 1;
};

bool EncodeJpegXl(const FuzzSpec& spec) {
  // Multi-threaded parallel runner. Limit to max 2 threads since the fuzzer
  // itself is already multithreaded.
  size_t num_threads =
      std::min<size_t>(2, JxlThreadParallelRunnerDefaultNumWorkerThreads());
  auto runner = JxlThreadParallelRunnerMake(nullptr, num_threads);
  JxlEncoderPtr enc_ptr = JxlEncoderMake(/*memory_manager=*/nullptr);
  JxlEncoder* enc = enc_ptr.get();
  for (size_t num_rep = 0; num_rep < 2; ++num_rep) {
    JxlEncoderReset(enc);
    TRY(JxlEncoderSetParallelRunner(enc, JxlThreadParallelRunner,
                                    runner.get()));
    JxlEncoderFrameSettings* frame_settings =
        JxlEncoderFrameSettingsCreate(enc, nullptr);

    for (auto option : spec.options) {
      TRY(JxlEncoderFrameSettingsSetOption(frame_settings, option.id,
                                           option.value));
    }

    TRY(JxlEncoderSetCodestreamLevel(enc, spec.codestream_level));
    JxlBasicInfo basic_info;
    JxlEncoderInitBasicInfo(&basic_info);
    basic_info.xsize = spec.xsize;
    basic_info.ysize = spec.ysize;
    basic_info.bits_per_sample = spec.bit_depth;
    basic_info.uses_original_profile = spec.orig_profile;
    if (spec.have_alpha) {
      basic_info.alpha_bits = spec.alpha_bit_depth;
      basic_info.num_extra_channels = 1;
    }
    TRY(JxlEncoderSetBasicInfo(enc, &basic_info));
    if (spec.lossless) {
      TRY(JxlEncoderSetFrameLossless(frame_settings, JXL_TRUE));
    }

    // TODO(szabadka) Add icc color profiles.
    TRY(JxlEncoderSetColorEncoding(enc, &spec.color_encoding));

    // TODO(szabadka) Add jpeg frames.
    for (size_t i = 0; i < spec.num_frames; ++i) {
      JxlFrameHeader frame_header;
      JxlEncoderInitFrameHeader(&frame_header);
      // TODO(szabadka) Add more frame header options.
      TRY(JxlEncoderSetFrameHeader(frame_settings, &frame_header));
      if (spec.have_alpha) {
        JxlExtraChannelInfo extra_channel_info;
        JxlEncoderInitExtraChannelInfo(JXL_CHANNEL_ALPHA, &extra_channel_info);
        TRY(JxlEncoderSetExtraChannelInfo(enc, 0, &extra_channel_info));
        extra_channel_info.alpha_premultiplied = spec.premultiply;
      }
      JxlPixelFormat pixelformat = {3, JXL_TYPE_UINT16, JXL_LITTLE_ENDIAN, 0};
      std::vector<uint8_t> pixels = jxl::test::GetSomeTestImage(
          spec.xsize, spec.ysize, 3, spec.pixels_seed);
      TRY(JxlEncoderAddImageFrame(frame_settings, &pixelformat, pixels.data(),
                                  pixels.size()));
      if (spec.have_alpha) {
        std::vector<uint8_t> alpha_pixels = jxl::test::GetSomeTestImage(
            spec.xsize, spec.ysize, 1, spec.alpha_seed);
        TRY(JxlEncoderSetExtraChannelBuffer(frame_settings, &pixelformat,
                                            alpha_pixels.data(),
                                            alpha_pixels.size(), 0));
      }
    }
    // Reading compressed output
    JxlEncoderStatus process_result = JXL_ENC_NEED_MORE_OUTPUT;
    while (process_result == JXL_ENC_NEED_MORE_OUTPUT) {
      std::vector<uint8_t> buf(spec.output_buffer_size + 32);
      uint8_t* next_out = buf.data();
      size_t avail_out = buf.size();
      process_result = JxlEncoderProcessOutput(enc, &next_out, &avail_out);
    }
    if (JXL_ENC_SUCCESS != process_result) {
      return false;
    }
  }
  return true;
}

template <typename T>
T Select(const std::vector<T>& vec, std::function<uint32_t(size_t)> get_index) {
  return vec[get_index(vec.size() - 1)];
}

int TestOneInput(const uint8_t* data, size_t size) {
  uint64_t flags = 0;
  size_t flag_bits = 0;

  const auto consume_data = [&]() {
    if (size < 4) abort();
    uint32_t buf = 0;
    memcpy(&buf, data, 4);
    data += 4;
    size -= 4;
    flags = (flags << 32) | buf;
    flag_bits += 32;
  };

  const auto get_flag = [&](size_t max_value) {
    size_t limit = 1;
    while (limit <= max_value) {
      limit <<= 1;
      --flag_bits;
      if (flag_bits <= 16) {
        consume_data();
      }
    }
    uint32_t result = flags % limit;
    flags /= limit;
    return result % (max_value + 1);
  };

  std::vector<JxlColorSpace> colorspaces = {
      JXL_COLOR_SPACE_RGB, JXL_COLOR_SPACE_GRAY, JXL_COLOR_SPACE_XYB,
      JXL_COLOR_SPACE_UNKNOWN};
  std::vector<JxlWhitePoint> whitepoints = {
      JXL_WHITE_POINT_D65, JXL_WHITE_POINT_CUSTOM, JXL_WHITE_POINT_E,
      JXL_WHITE_POINT_DCI};
  std::vector<JxlPrimaries> primaries = {JXL_PRIMARIES_SRGB,
                                         JXL_PRIMARIES_CUSTOM,
                                         JXL_PRIMARIES_2100, JXL_PRIMARIES_P3};
  std::vector<JxlTransferFunction> transfer_functions = {
      JXL_TRANSFER_FUNCTION_709,    JXL_TRANSFER_FUNCTION_UNKNOWN,
      JXL_TRANSFER_FUNCTION_LINEAR, JXL_TRANSFER_FUNCTION_SRGB,
      JXL_TRANSFER_FUNCTION_PQ,     JXL_TRANSFER_FUNCTION_DCI,
      JXL_TRANSFER_FUNCTION_HLG,    JXL_TRANSFER_FUNCTION_GAMMA};
  std::vector<JxlRenderingIntent> rendering_intents = {
      JXL_RENDERING_INTENT_PERCEPTUAL,
      JXL_RENDERING_INTENT_RELATIVE,
      JXL_RENDERING_INTENT_SATURATION,
      JXL_RENDERING_INTENT_ABSOLUTE,
  };

  FuzzSpec spec;
  // Randomly set some options.
  // TODO(szabadka) Make value bounds option specific.
  size_t num_options = get_flag(32);
  for (size_t i = 0; i < num_options; ++i) {
    FuzzSpec::OptionSpec option;
    option.id = static_cast<JxlEncoderFrameSettingId>(get_flag(32));
    option.value = static_cast<int32_t>(get_flag(16)) - 1;
    spec.options.push_back(option);
  }

  spec.xsize = get_flag(4095) + 1;
  spec.ysize = get_flag(4095) + 1;
  spec.lossless = get_flag(1);
  if (!spec.lossless) {
    spec.orig_profile = get_flag(1);
  }
  spec.have_alpha = get_flag(1);
  spec.premultiply = get_flag(1);
  spec.pixels_seed = get_flag((1 << 16) - 1);
  spec.alpha_seed = get_flag((1 << 16) - 1);
  spec.bit_depth = get_flag(15) + 1;
  spec.alpha_bit_depth = get_flag(15) + 1;
  spec.color_encoding.color_space = Select(colorspaces, get_flag);
  spec.color_encoding.white_point = Select(whitepoints, get_flag);
  spec.color_encoding.primaries = Select(primaries, get_flag);
  spec.color_encoding.transfer_function = Select(transfer_functions, get_flag);
  spec.color_encoding.rendering_intent = Select(rendering_intents, get_flag);
  spec.output_buffer_size = get_flag(4095) + 1;

  const auto targets = hwy::SupportedAndGeneratedTargets();
  hwy::SetSupportedTargetsForTest(Select(targets, get_flag));
  EncodeJpegXl(spec);
  hwy::SetSupportedTargetsForTest(0);

  return 0;
}

}  // namespace

extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size) {
  return TestOneInput(data, size);
}
