// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.
#include "tools/benchmark/benchmark_codec_jpeg.h"

#include <stddef.h>
#include <stdio.h>
// After stddef/stdio
#include <stdint.h>
#include <string.h>

#include <numeric>  // partial_sum
#include <string>

#if JPEGXL_ENABLE_JPEGLI
#include "lib/extras/dec/jpegli.h"
#endif
#include "lib/extras/dec/jpg.h"
#if JPEGXL_ENABLE_JPEGLI
#include "lib/extras/enc/jpegli.h"
#endif
#include "lib/extras/enc/jpg.h"
#include "lib/extras/packed_image.h"
#include "lib/extras/packed_image_convert.h"
#include "lib/extras/time.h"
#include "lib/jxl/base/padded_bytes.h"
#include "lib/jxl/base/span.h"
#include "lib/jxl/codec_in_out.h"
#include "lib/jxl/image_bundle.h"
#include "tools/benchmark/benchmark_utils.h"
#include "tools/cmdline.h"
#include "tools/file_io.h"
#include "tools/thread_pool_internal.h"

namespace jpegxl {
namespace tools {

struct JPEGArgs {
  std::string base_quant_fn;
  float search_q_start;
  float search_q_min;
  float search_q_max;
  float search_d_min;
  float search_d_max;
  int search_max_iters;
  float search_tolerance;
  float search_q_precision;
  float search_first_iter_slope;
};

static JPEGArgs* const jpegargs = new JPEGArgs;

#define SET_ENCODER_ARG(name)                                  \
  if (jpegargs->name > 0) {                                    \
    encoder->SetOption(#name, std::to_string(jpegargs->name)); \
  }

Status AddCommandLineOptionsJPEGCodec(BenchmarkArgs* args) {
  args->AddString(&jpegargs->base_quant_fn, "qtables",
                  "Custom base quantization tables.");
  args->AddFloat(&jpegargs->search_q_start, "search_q_start",
                 "Starting quality for quality-to-target search", 0.0f);
  args->AddFloat(&jpegargs->search_q_min, "search_q_min",
                 "Minimum quality for quality-to-target search", 0.0f);
  args->AddFloat(&jpegargs->search_q_max, "search_q_max",
                 "Maximum quality for quality-to-target search", 0.0f);
  args->AddFloat(&jpegargs->search_d_min, "search_d_min",
                 "Minimum distance for quality-to-target search", 0.0f);
  args->AddFloat(&jpegargs->search_d_max, "search_d_max",
                 "Maximum distance for quality-to-target search", 0.0f);
  args->AddFloat(&jpegargs->search_tolerance, "search_tolerance",
                 "Percentage value, if quality-to-target search result "
                 "relative error is within this, search stops.",
                 0.0f);
  args->AddFloat(&jpegargs->search_q_precision, "search_q_precision",
                 "If last quality change in quality-to-target search is "
                 "within this value, search stops.",
                 0.0f);
  args->AddFloat(&jpegargs->search_first_iter_slope, "search_first_iter_slope",
                 "Slope of first extrapolation step in quality-to-target "
                 "search.",
                 0.0f);
  args->AddSigned(&jpegargs->search_max_iters, "search_max_iters",
                  "Maximum search steps in quality-to-target search.", 0);
  return true;
}

class JPEGCodec : public ImageCodec {
 public:
  explicit JPEGCodec(const BenchmarkArgs& args) : ImageCodec(args) {}

  Status ParseParam(const std::string& param) override {
    if (param[0] == 'q' && ImageCodec::ParseParam(param)) {
      enc_quality_set_ = true;
      return true;
    }
    if (ImageCodec::ParseParam(param)) {
      return true;
    }
    if (param == "sjpeg" || param.find("cjpeg") != std::string::npos) {
      jpeg_encoder_ = param;
      return true;
    }
#if JPEGXL_ENABLE_JPEGLI
    if (param == "enc-jpegli") {
      jpeg_encoder_ = "jpegli";
      return true;
    }
#endif
    if (param.compare(0, 3, "yuv") == 0) {
      chroma_subsampling_ = param.substr(3);
      return true;
    }
    if (param.compare(0, 4, "psnr") == 0) {
      psnr_target_ = std::stof(param.substr(4));
      return true;
    }
    if (param[0] == 'p') {
      progressive_id_ = strtol(param.substr(1).c_str(), nullptr, 10);
      return true;
    }
    if (param == "fix") {
      fix_codes_ = true;
      return true;
    }
    if (param[0] == 'Q') {
      libjpeg_quality_ = strtol(param.substr(1).c_str(), nullptr, 10);
      return true;
    }
    if (param.compare(0, 3, "YUV") == 0) {
      if (param.size() != 6) return false;
      libjpeg_chroma_subsampling_ = param.substr(3);
      return true;
    }
    if (param == "noaq") {
      enable_adaptive_quant_ = false;
      return true;
    }
#if JPEGXL_ENABLE_JPEGLI
    if (param == "xyb") {
      xyb_mode_ = true;
      return true;
    }
    if (param == "std") {
      use_std_tables_ = true;
      return true;
    }
    if (param == "dec-jpegli") {
      jpeg_decoder_ = "jpegli";
      return true;
    }
    if (param.substr(0, 2) == "bd") {
      bitdepth_ = strtol(param.substr(2).c_str(), nullptr, 10);
      return true;
    }
    if (param.substr(0, 6) == "cquant") {
      num_colors_ = strtol(param.substr(6).c_str(), nullptr, 10);
      return true;
    }
#endif
    return false;
  }

  bool IgnoreAlpha() const override { return true; }

  Status Compress(const std::string& filename, const CodecInOut* io,
                  ThreadPool* pool, std::vector<uint8_t>* compressed,
                  jpegxl::tools::SpeedStats* speed_stats) override {
    if (jpeg_encoder_.find("cjpeg") != std::string::npos) {
// Not supported on Windows due to Linux-specific functions.
// Not supported in Android NDK before API 28.
#if !defined(_WIN32) && !defined(__EMSCRIPTEN__) && \
    (!defined(__ANDROID_API__) || __ANDROID_API__ >= 28)
      const std::string basename = GetBaseName(filename);
      TemporaryFile in_file(basename, "pnm");
      TemporaryFile encoded_file(basename, "jpg");
      std::string in_filename, encoded_filename;
      JXL_RETURN_IF_ERROR(in_file.GetFileName(&in_filename));
      JXL_RETURN_IF_ERROR(encoded_file.GetFileName(&encoded_filename));
      const size_t bits = io->metadata.m.bit_depth.bits_per_sample;
      ColorEncoding c_enc = io->Main().c_current();
      std::vector<uint8_t> encoded;
      JXL_RETURN_IF_ERROR(
          Encode(*io, c_enc, bits, in_filename, &encoded, pool));
      JXL_RETURN_IF_ERROR(WriteFile(in_filename, encoded));
      std::string compress_command = jpeg_encoder_;
      std::vector<std::string> arguments;
      arguments.push_back("-outfile");
      arguments.push_back(encoded_filename);
      arguments.push_back("-quality");
      arguments.push_back(std::to_string(static_cast<int>(q_target_)));
      arguments.push_back("-sample");
      if (chroma_subsampling_ == "444") {
        arguments.push_back("1x1");
      } else if (chroma_subsampling_ == "420") {
        arguments.push_back("2x2");
      } else if (!chroma_subsampling_.empty()) {
        return JXL_FAILURE("Unsupported chroma subsampling");
      }
      arguments.push_back("-optimize");
      arguments.push_back(in_filename);
      const double start = jxl::Now();
      JXL_RETURN_IF_ERROR(RunCommand(compress_command, arguments, false));
      const double end = jxl::Now();
      speed_stats->NotifyElapsed(end - start);
      return ReadFile(encoded_filename, compressed);
#else
      return JXL_FAILURE("Not supported on this build");
#endif
    }

    jxl::extras::PackedPixelFile ppf;
    size_t bits_per_sample = io->metadata.m.bit_depth.bits_per_sample;
    JxlPixelFormat format = {
        0,  // num_channels is ignored by the converter
        bits_per_sample <= 8 ? JXL_TYPE_UINT8 : JXL_TYPE_UINT16, JXL_BIG_ENDIAN,
        0};
    JXL_RETURN_IF_ERROR(ConvertCodecInOutToPackedPixelFile(
        *io, format, io->metadata.m.color_encoding, pool, &ppf));
    double elapsed = 0.0;
    if (jpeg_encoder_ == "jpegli") {
#if JPEGXL_ENABLE_JPEGLI
      jxl::extras::JpegSettings settings;
      settings.xyb = xyb_mode_;
      if (!xyb_mode_) {
        settings.use_std_quant_tables = use_std_tables_;
      }
      if (enc_quality_set_) {
        settings.quality = q_target_;
      } else {
        settings.distance = butteraugli_target_;
      }
      if (progressive_id_ >= 0) {
        settings.progressive_level = progressive_id_;
      }
      if (psnr_target_ > 0) {
        settings.psnr_target = psnr_target_;
      }
      if (jpegargs->search_tolerance > 0) {
        settings.search_tolerance = 0.01f * jpegargs->search_tolerance;
      }
      if (jpegargs->search_d_min > 0) {
        settings.min_distance = jpegargs->search_d_min;
      }
      if (jpegargs->search_d_max > 0) {
        settings.max_distance = jpegargs->search_d_max;
      }
      settings.chroma_subsampling = chroma_subsampling_;
      settings.use_adaptive_quantization = enable_adaptive_quant_;
      settings.libjpeg_quality = libjpeg_quality_;
      settings.libjpeg_chroma_subsampling = libjpeg_chroma_subsampling_;
      settings.optimize_coding = !fix_codes_;
      const double start = jxl::Now();
      JXL_RETURN_IF_ERROR(
          jxl::extras::EncodeJpeg(ppf, settings, pool, compressed));
      const double end = jxl::Now();
      elapsed = end - start;
#endif
    } else {
      jxl::extras::EncodedImage encoded;
      std::unique_ptr<jxl::extras::Encoder> encoder =
          jxl::extras::GetJPEGEncoder();
      if (!encoder) {
        fprintf(stderr, "libjpeg codec is not supported\n");
        return false;
      }
      std::ostringstream os;
      os << static_cast<int>(std::round(q_target_));
      encoder->SetOption("q", os.str());
      encoder->SetOption("jpeg_encoder", jpeg_encoder_);
      if (!chroma_subsampling_.empty()) {
        encoder->SetOption("chroma_subsampling", chroma_subsampling_);
      }
      if (progressive_id_ >= 0) {
        encoder->SetOption("progressive", std::to_string(progressive_id_));
      }
      if (libjpeg_quality_ > 0) {
        encoder->SetOption("libjpeg_quality", std::to_string(libjpeg_quality_));
      }
      if (!libjpeg_chroma_subsampling_.empty()) {
        encoder->SetOption("libjpeg_chroma_subsampling",
                           libjpeg_chroma_subsampling_);
      }
      if (fix_codes_) {
        encoder->SetOption("optimize", "OFF");
      }
      if (!enable_adaptive_quant_) {
        encoder->SetOption("adaptive_q", "OFF");
      }
      if (psnr_target_ > 0) {
        encoder->SetOption("psnr", std::to_string(psnr_target_));
      }
      if (!jpegargs->base_quant_fn.empty()) {
        encoder->SetOption("base_quant_fn", jpegargs->base_quant_fn);
      }
      SET_ENCODER_ARG(search_q_start);
      SET_ENCODER_ARG(search_q_min);
      SET_ENCODER_ARG(search_q_max);
      SET_ENCODER_ARG(search_q_precision);
      SET_ENCODER_ARG(search_tolerance);
      SET_ENCODER_ARG(search_first_iter_slope);
      SET_ENCODER_ARG(search_max_iters);
      const double start = jxl::Now();
      JXL_RETURN_IF_ERROR(encoder->Encode(ppf, &encoded, pool));
      const double end = jxl::Now();
      elapsed = end - start;
      *compressed = encoded.bitstreams.back();
    }
    speed_stats->NotifyElapsed(elapsed);
    return true;
  }

  Status Decompress(const std::string& filename,
                    const Span<const uint8_t> compressed, ThreadPool* pool,
                    CodecInOut* io,
                    jpegxl::tools::SpeedStats* speed_stats) override {
    jxl::extras::PackedPixelFile ppf;
    if (jpeg_decoder_ == "jpegli") {
#if JPEGXL_ENABLE_JPEGLI
      std::vector<uint8_t> jpeg_bytes(compressed.data(),
                                      compressed.data() + compressed.size());
      const double start = jxl::Now();
      jxl::extras::JpegDecompressParams dparams;
      dparams.output_data_type =
          bitdepth_ > 8 ? JXL_TYPE_UINT16 : JXL_TYPE_UINT8;
      dparams.num_colors = num_colors_;
      JXL_RETURN_IF_ERROR(
          jxl::extras::DecodeJpeg(jpeg_bytes, dparams, pool, &ppf));
      const double end = jxl::Now();
      speed_stats->NotifyElapsed(end - start);
#endif
    } else {
      const double start = jxl::Now();
      jxl::extras::JPGDecompressParams dparams;
      dparams.num_colors = num_colors_;
      JXL_RETURN_IF_ERROR(
          jxl::extras::DecodeImageJPG(compressed, jxl::extras::ColorHints(),
                                      &ppf, /*constraints=*/nullptr, &dparams));
      const double end = jxl::Now();
      speed_stats->NotifyElapsed(end - start);
    }
    JXL_RETURN_IF_ERROR(
        jxl::extras::ConvertPackedPixelFileToCodecInOut(ppf, pool, io));
    return true;
  }

 protected:
  // JPEG encoder and its parameters
  std::string jpeg_encoder_ = "libjpeg";
  std::string chroma_subsampling_;
  int progressive_id_ = -1;
  bool fix_codes_ = false;
  float psnr_target_ = 0.0f;
  bool enc_quality_set_ = false;
  int libjpeg_quality_ = 0;
  std::string libjpeg_chroma_subsampling_;
#if JPEGXL_ENABLE_JPEGLI
  bool xyb_mode_ = false;
  bool use_std_tables_ = false;
#endif
  bool enable_adaptive_quant_ = true;
  // JPEG decoder and its parameters
  std::string jpeg_decoder_ = "libjpeg";
  int num_colors_ = 0;
#if JPEGXL_ENABLE_JPEGLI
  size_t bitdepth_ = 8;
#endif
};

ImageCodec* CreateNewJPEGCodec(const BenchmarkArgs& args) {
  return new JPEGCodec(args);
}

}  // namespace tools
}  // namespace jpegxl
