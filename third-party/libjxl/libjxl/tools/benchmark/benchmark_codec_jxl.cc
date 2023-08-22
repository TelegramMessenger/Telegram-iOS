// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.
#include "tools/benchmark/benchmark_codec_jxl.h"

#include <jxl/stats.h>
#include <jxl/thread_parallel_runner_cxx.h>

#include <cstdint>
#include <cstdlib>
#include <functional>
#include <sstream>
#include <string>
#include <utility>
#include <vector>

#include "lib/extras/codec.h"
#include "lib/extras/dec/jxl.h"
#include "lib/extras/enc/apng.h"
#include "lib/extras/enc/encode.h"
#include "lib/extras/enc/jpg.h"
#include "lib/extras/enc/jxl.h"
#include "lib/extras/packed_image_convert.h"
#include "lib/extras/time.h"
#include "lib/jxl/base/data_parallel.h"
#include "lib/jxl/base/override.h"
#include "lib/jxl/base/span.h"
#include "lib/jxl/codec_in_out.h"
#include "tools/benchmark/benchmark_file_io.h"
#include "tools/benchmark/benchmark_stats.h"
#include "tools/cmdline.h"

namespace jpegxl {
namespace tools {

using ::jxl::Image3F;
using ::jxl::extras::EncodedImage;
using ::jxl::extras::Encoder;
using ::jxl::extras::JXLCompressParams;
using ::jxl::extras::JXLDecompressParams;
using ::jxl::extras::PackedFrame;
using ::jxl::extras::PackedPixelFile;

struct JxlArgs {
  bool qprogressive;  // progressive with shift-quantization.
  bool progressive;
  int progressive_dc;

  Override noise;
  Override dots;
  Override patches;

  std::string debug_image_dir;
};

static JxlArgs* const jxlargs = new JxlArgs;

Status AddCommandLineOptionsJxlCodec(BenchmarkArgs* args) {
  args->AddFlag(&jxlargs->qprogressive, "qprogressive",
                "Enable quantized progressive mode for AC.", false);
  args->AddFlag(&jxlargs->progressive, "progressive",
                "Enable progressive mode for AC.", false);
  args->AddSigned(&jxlargs->progressive_dc, "progressive_dc",
                  "Enable progressive mode for DC.", -1);

  args->AddOverride(&jxlargs->noise, "noise",
                    "Enable(1)/disable(0) noise generation.");
  args->AddOverride(&jxlargs->dots, "dots",
                    "Enable(1)/disable(0) dots generation.");
  args->AddOverride(&jxlargs->patches, "patches",
                    "Enable(1)/disable(0) patch dictionary.");

  args->AddString(
      &jxlargs->debug_image_dir, "debug_image_dir",
      "If not empty, saves debug images for each "
      "input image and each codec that provides it to this directory.");

  return true;
}

Status ValidateArgsJxlCodec(BenchmarkArgs* args) { return true; }

inline bool ParseEffort(const std::string& s, int* out) {
  if (s == "lightning") {
    *out = 1;
    return true;
  } else if (s == "thunder") {
    *out = 2;
    return true;
  } else if (s == "falcon") {
    *out = 3;
    return true;
  } else if (s == "cheetah") {
    *out = 4;
    return true;
  } else if (s == "hare") {
    *out = 5;
    return true;
  } else if (s == "fast" || s == "wombat") {
    *out = 6;
    return true;
  } else if (s == "squirrel") {
    *out = 7;
    return true;
  } else if (s == "kitten") {
    *out = 8;
    return true;
  } else if (s == "guetzli" || s == "tortoise") {
    *out = 9;
    return true;
  } else if (s == "glacier") {
    *out = 10;
    return true;
  }
  size_t st = static_cast<size_t>(strtoull(s.c_str(), nullptr, 0));
  if (st <= 10 && st >= 1) {
    *out = st;
    return true;
  }
  return false;
}

class JxlCodec : public ImageCodec {
 public:
  explicit JxlCodec(const BenchmarkArgs& args)
      : ImageCodec(args), stats_(nullptr, JxlEncoderStatsDestroy) {}

  Status ParseParam(const std::string& param) override {
    const std::string kMaxPassesPrefix = "max_passes=";
    const std::string kDownsamplingPrefix = "downsampling=";
    const std::string kResamplingPrefix = "resampling=";
    const std::string kEcResamplingPrefix = "ec_resampling=";
    int val;
    float fval;
    if (param.substr(0, kResamplingPrefix.size()) == kResamplingPrefix) {
      std::istringstream parser(param.substr(kResamplingPrefix.size()));
      int resampling;
      parser >> resampling;
      cparams_.AddOption(JXL_ENC_FRAME_SETTING_RESAMPLING, resampling);
    } else if (param.substr(0, kEcResamplingPrefix.size()) ==
               kEcResamplingPrefix) {
      std::istringstream parser(param.substr(kEcResamplingPrefix.size()));
      int ec_resampling;
      parser >> ec_resampling;
      cparams_.AddOption(JXL_ENC_FRAME_SETTING_EXTRA_CHANNEL_RESAMPLING,
                         ec_resampling);
    } else if (ImageCodec::ParseParam(param)) {
      // Nothing to do.
    } else if (param == "uint8") {
      uint8_ = true;
    } else if (param[0] == 'D') {
      cparams_.alpha_distance = strtof(param.substr(1).c_str(), nullptr);
    } else if (param.substr(0, kMaxPassesPrefix.size()) == kMaxPassesPrefix) {
      std::istringstream parser(param.substr(kMaxPassesPrefix.size()));
      parser >> dparams_.max_passes;
    } else if (param.substr(0, kDownsamplingPrefix.size()) ==
               kDownsamplingPrefix) {
      std::istringstream parser(param.substr(kDownsamplingPrefix.size()));
      parser >> dparams_.max_downsampling;
    } else if (ParseEffort(param, &val)) {
      cparams_.AddOption(JXL_ENC_FRAME_SETTING_EFFORT, val);
    } else if (param[0] == 'X') {
      fval = strtof(param.substr(1).c_str(), nullptr);
      cparams_.AddFloatOption(
          JXL_ENC_FRAME_SETTING_CHANNEL_COLORS_GLOBAL_PERCENT, fval);
    } else if (param[0] == 'Y') {
      fval = strtof(param.substr(1).c_str(), nullptr);
      cparams_.AddFloatOption(
          JXL_ENC_FRAME_SETTING_CHANNEL_COLORS_GROUP_PERCENT, fval);
    } else if (param[0] == 'p') {
      val = strtol(param.substr(1).c_str(), nullptr, 10);
      cparams_.AddOption(JXL_ENC_FRAME_SETTING_PALETTE_COLORS, val);
    } else if (param == "lp") {
      cparams_.AddOption(JXL_ENC_FRAME_SETTING_LOSSY_PALETTE, 1);
    } else if (param[0] == 'C') {
      val = strtol(param.substr(1).c_str(), nullptr, 10);
      cparams_.AddOption(JXL_ENC_FRAME_SETTING_MODULAR_COLOR_SPACE, val);
    } else if (param[0] == 'c') {
      val = strtol(param.substr(1).c_str(), nullptr, 10);
      cparams_.AddOption(JXL_ENC_FRAME_SETTING_COLOR_TRANSFORM, val);
      has_ctransform_ = true;
    } else if (param[0] == 'I') {
      fval = strtof(param.substr(1).c_str(), nullptr);
      cparams_.AddFloatOption(
          JXL_ENC_FRAME_SETTING_MODULAR_MA_TREE_LEARNING_PERCENT, fval * 100.0);
    } else if (param[0] == 'E') {
      val = strtol(param.substr(1).c_str(), nullptr, 10);
      cparams_.AddOption(JXL_ENC_FRAME_SETTING_MODULAR_NB_PREV_CHANNELS, val);
    } else if (param[0] == 'P') {
      val = strtol(param.substr(1).c_str(), nullptr, 10);
      cparams_.AddOption(JXL_ENC_FRAME_SETTING_MODULAR_PREDICTOR, val);
    } else if (param == "slow") {
      cparams_.AddFloatOption(
          JXL_ENC_FRAME_SETTING_MODULAR_MA_TREE_LEARNING_PERCENT, 50.0);
    } else if (param == "R") {
      cparams_.AddOption(JXL_ENC_FRAME_SETTING_RESPONSIVE, 1);
    } else if (param[0] == 'R') {
      val = strtol(param.substr(1).c_str(), nullptr, 10);
      cparams_.AddOption(JXL_ENC_FRAME_SETTING_RESPONSIVE, val);
    } else if (param == "m") {
      cparams_.AddOption(JXL_ENC_FRAME_SETTING_MODULAR, 1);
      cparams_.AddOption(JXL_ENC_FRAME_SETTING_COLOR_TRANSFORM, 1);  // kNone
      modular_mode_ = true;
    } else if (param.substr(0, 3) == "gab") {
      val = strtol(param.substr(3).c_str(), nullptr, 10);
      if (val != 0 && val != 1) {
        return JXL_FAILURE("Invalid gab value");
      }
      cparams_.AddOption(JXL_ENC_FRAME_SETTING_GABORISH, val);
    } else if (param[0] == 'g') {
      val = strtol(param.substr(1).c_str(), nullptr, 10);
      if (val < 0 || val > 3) {
        return JXL_FAILURE("Invalid group size shift value");
      }
      cparams_.AddOption(JXL_ENC_FRAME_SETTING_MODULAR_GROUP_SIZE, val);
    } else if (param == "plt") {
      cparams_.AddOption(JXL_ENC_FRAME_SETTING_MODULAR_NB_PREV_CHANNELS, 0);
      cparams_.AddFloatOption(
          JXL_ENC_FRAME_SETTING_MODULAR_MA_TREE_LEARNING_PERCENT, 0.0f);
      cparams_.AddOption(JXL_ENC_FRAME_SETTING_MODULAR_PREDICTOR, 0);
      cparams_.AddOption(JXL_ENC_FRAME_SETTING_RESPONSIVE, 0);
      cparams_.AddOption(JXL_ENC_FRAME_SETTING_MODULAR_COLOR_SPACE, 0);
      cparams_.AddOption(JXL_ENC_FRAME_SETTING_CHANNEL_COLORS_GLOBAL_PERCENT,
                         0);
      cparams_.AddOption(JXL_ENC_FRAME_SETTING_CHANNEL_COLORS_GROUP_PERCENT, 0);
    } else if (param.substr(0, 3) == "epf") {
      val = strtol(param.substr(3).c_str(), nullptr, 10);
      if (val > 3) {
        return JXL_FAILURE("Invalid epf value");
      }
      cparams_.AddOption(JXL_ENC_FRAME_SETTING_EPF, val);
    } else if (param.substr(0, 16) == "faster_decoding=") {
      val = strtol(param.substr(16).c_str(), nullptr, 10);
      cparams_.AddOption(JXL_ENC_FRAME_SETTING_DECODING_SPEED, val);
    } else {
      return JXL_FAILURE("Unrecognized param");
    }
    return true;
  }

  Status Compress(const std::string& filename, const CodecInOut* io,
                  ThreadPool* pool, std::vector<uint8_t>* compressed,
                  jpegxl::tools::SpeedStats* speed_stats) override {
    PackedPixelFile ppf;
    JxlPixelFormat format{0, JXL_TYPE_FLOAT, JXL_NATIVE_ENDIAN, 0};
    JXL_RETURN_IF_ERROR(ConvertCodecInOutToPackedPixelFile(
        *io, format, io->Main().c_current(), pool, &ppf));
    cparams_.runner = pool->runner();
    cparams_.runner_opaque = pool->runner_opaque();
    cparams_.distance = butteraugli_target_;
    cparams_.AddOption(JXL_ENC_FRAME_SETTING_NOISE, (int)jxlargs->noise);
    cparams_.AddOption(JXL_ENC_FRAME_SETTING_DOTS, (int)jxlargs->dots);
    cparams_.AddOption(JXL_ENC_FRAME_SETTING_PATCHES, (int)jxlargs->patches);
    cparams_.AddOption(JXL_ENC_FRAME_SETTING_PROGRESSIVE_AC,
                       jxlargs->progressive);
    cparams_.AddOption(JXL_ENC_FRAME_SETTING_QPROGRESSIVE_AC,
                       jxlargs->qprogressive);
    cparams_.AddOption(JXL_ENC_FRAME_SETTING_PROGRESSIVE_DC,
                       jxlargs->progressive_dc);
    if (butteraugli_target_ > 0.f && modular_mode_ && !has_ctransform_) {
      // Reset color transform to default XYB for lossy modular.
      cparams_.AddOption(JXL_ENC_FRAME_SETTING_COLOR_TRANSFORM, -1);
    }
    std::string debug_prefix;
    SetDebugImageCallback(filename, &debug_prefix, &cparams_);
    if (args_.print_more_stats) {
      stats_.reset(JxlEncoderStatsCreate());
      cparams_.stats = stats_.get();
    }
    const double start = jxl::Now();
    JXL_RETURN_IF_ERROR(jxl::extras::EncodeImageJXL(
        cparams_, ppf, /*jpeg_bytes=*/nullptr, compressed));
    const double end = jxl::Now();
    speed_stats->NotifyElapsed(end - start);
    return true;
  }

  Status Decompress(const std::string& filename,
                    const Span<const uint8_t> compressed, ThreadPool* pool,
                    CodecInOut* io,
                    jpegxl::tools::SpeedStats* speed_stats) override {
    dparams_.runner = pool->runner();
    dparams_.runner_opaque = pool->runner_opaque();
    JxlDataType data_type = uint8_ ? JXL_TYPE_UINT8 : JXL_TYPE_FLOAT;
    dparams_.accepted_formats = {{3, data_type, JXL_NATIVE_ENDIAN, 0},
                                 {4, data_type, JXL_NATIVE_ENDIAN, 0}};
    // By default, the decoder will undo exif orientation, giving an image
    // with identity exif rotation as result. However, the benchmark does
    // not undo exif orientation of the originals, and compares against the
    // originals, so we must set the option to keep the original orientation
    // instead.
    dparams_.keep_orientation = true;
    PackedPixelFile ppf;
    size_t decoded_bytes;
    const double start = jxl::Now();
    JXL_RETURN_IF_ERROR(jxl::extras::DecodeImageJXL(
        compressed.data(), compressed.size(), dparams_, &decoded_bytes, &ppf));
    const double end = jxl::Now();
    speed_stats->NotifyElapsed(end - start);
    JXL_RETURN_IF_ERROR(ConvertPackedPixelFileToCodecInOut(ppf, pool, io));
    return true;
  }

  void GetMoreStats(BenchmarkStats* stats) override {
    stats->jxl_stats.num_inputs += 1;
    JxlEncoderStatsMerge(stats->jxl_stats.stats.get(), stats_.get());
  }

 protected:
  JXLCompressParams cparams_;
  bool has_ctransform_ = false;
  bool modular_mode_ = false;
  JXLDecompressParams dparams_;
  bool uint8_ = false;
  std::unique_ptr<JxlEncoderStats, decltype(JxlEncoderStatsDestroy)*> stats_;

 private:
  void SetDebugImageCallback(const std::string& filename,
                             std::string* debug_prefix,
                             JXLCompressParams* cparams) {
    if (jxlargs->debug_image_dir.empty()) return;
    *debug_prefix = JoinPath(jxlargs->debug_image_dir, FileBaseName(filename)) +
                    ".jxl:" + params_ + ".dbg/";
    JXL_CHECK(MakeDir(*debug_prefix));
    cparams->debug_image_opaque = debug_prefix;
    cparams->debug_image = [](void* opaque, const char* label, size_t xsize,
                              size_t ysize, const JxlColorEncoding* color,
                              const uint16_t* pixels) {
      auto encoder = jxl::extras::GetAPNGEncoder();
      JXL_CHECK(encoder);
      PackedPixelFile debug_ppf;
      JxlPixelFormat format{3, JXL_TYPE_UINT16, JXL_BIG_ENDIAN, 0};
      PackedFrame frame(xsize, ysize, format);
      memcpy(frame.color.pixels(), pixels, 6 * xsize * ysize);
      debug_ppf.frames.emplace_back(std::move(frame));
      debug_ppf.info.xsize = xsize;
      debug_ppf.info.ysize = ysize;
      debug_ppf.info.num_color_channels = 3;
      debug_ppf.info.bits_per_sample = 16;
      debug_ppf.color_encoding = *color;
      EncodedImage encoded;
      JXL_CHECK(encoder->Encode(debug_ppf, &encoded));
      JXL_CHECK(!encoded.bitstreams.empty());
      std::string* debug_prefix = reinterpret_cast<std::string*>(opaque);
      std::string fn = *debug_prefix + std::string(label) + ".png";
      WriteFile(fn, encoded.bitstreams[0]);
    };
  }
};

ImageCodec* CreateNewJxlCodec(const BenchmarkArgs& args) {
  return new JxlCodec(args);
}

}  // namespace tools
}  // namespace jpegxl
