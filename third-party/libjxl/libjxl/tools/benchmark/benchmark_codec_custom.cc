// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "tools/benchmark/benchmark_codec_custom.h"

// Not supported on Windows due to Linux-specific functions.
#ifndef _WIN32

#include <libgen.h>

#include <fstream>

#include "lib/extras/codec.h"
#include "lib/extras/dec/color_description.h"
#include "lib/extras/enc/apng.h"
#include "lib/extras/time.h"
#include "lib/jxl/codec_in_out.h"
#include "lib/jxl/image_bundle.h"
#include "tools/benchmark/benchmark_utils.h"
#include "tools/file_io.h"
#include "tools/thread_pool_internal.h"

namespace jpegxl {
namespace tools {

struct CustomCodecArgs {
  std::string extension;
  std::string colorspace;
  bool quiet;
};

static CustomCodecArgs* const custom_args = new CustomCodecArgs;

Status AddCommandLineOptionsCustomCodec(BenchmarkArgs* args) {
  args->AddString(
      &custom_args->extension, "custom_codec_extension",
      "Converts input and output of codec to this file type (default: png).",
      "png");
  args->AddString(
      &custom_args->colorspace, "custom_codec_colorspace",
      "If not empty, converts input and output of codec to this colorspace.",
      "");
  args->AddFlag(&custom_args->quiet, "custom_codec_quiet",
                "Whether stdin and stdout of custom codec should be shown.",
                false);
  return true;
}

namespace {

// This uses `output_filename` to determine the name of the corresponding
// `.time` file.
template <typename F>
Status ReportCodecRunningTime(F&& function, std::string output_filename,
                              jpegxl::tools::SpeedStats* const speed_stats) {
  const double start = jxl::Now();
  JXL_RETURN_IF_ERROR(function());
  const double end = jxl::Now();
  const std::string time_filename =
      GetBaseName(std::move(output_filename)) + ".time";
  std::ifstream time_stream(time_filename);
  double time;
  if (time_stream >> time) {
    // Report the time measured by the external codec itself.
    speed_stats->NotifyElapsed(time);
  } else {
    // Fall back to the less accurate time that we measured.
    speed_stats->NotifyElapsed(end - start);
  }
  if (time_stream.is_open()) {
    remove(time_filename.c_str());
  }
  return true;
}

class CustomCodec : public ImageCodec {
 public:
  explicit CustomCodec(const BenchmarkArgs& args) : ImageCodec(args) {}

  Status ParseParam(const std::string& param) override {
    if (param_index_ == 0) {
      description_ = "";
    }
    switch (param_index_) {
      case 0:
        extension_ = param;
        description_ += param;
        break;
      case 1:
        compress_command_ = param;
        description_ += std::string(":");
        if (param.find_last_of('/') < param.size()) {
          description_ += param.substr(param.find_last_of('/') + 1);
        } else {
          description_ += param;
        }
        break;
      case 2:
        decompress_command_ = param;
        break;
      default:
        compress_args_.push_back(param);
        description_ += std::string(":");
        if (param.size() > 2 && param[0] == '-' && param[1] == '-') {
          description_ += param.substr(2);
        } else if (param.size() > 2 && param[0] == '-') {
          description_ += param.substr(1);
        } else {
          description_ += param;
        }
        break;
    }
    ++param_index_;
    return true;
  }

  Status Compress(const std::string& filename, const CodecInOut* io,
                  ThreadPool* pool, std::vector<uint8_t>* compressed,
                  jpegxl::tools::SpeedStats* speed_stats) override {
    JXL_RETURN_IF_ERROR(param_index_ > 2);

    const std::string basename = GetBaseName(filename);
    TemporaryFile in_file(basename, custom_args->extension);
    TemporaryFile encoded_file(basename, extension_);
    std::string in_filename, encoded_filename;
    JXL_RETURN_IF_ERROR(in_file.GetFileName(&in_filename));
    JXL_RETURN_IF_ERROR(encoded_file.GetFileName(&encoded_filename));
    saved_intensity_target_ = io->metadata.m.IntensityTarget();

    const size_t bits = io->metadata.m.bit_depth.bits_per_sample;
    ColorEncoding c_enc = io->Main().c_current();
    if (!custom_args->colorspace.empty()) {
      JxlColorEncoding colorspace;
      JXL_RETURN_IF_ERROR(
          jxl::ParseDescription(custom_args->colorspace, &colorspace));
      JXL_RETURN_IF_ERROR(
          jxl::ConvertExternalToInternalColorEncoding(colorspace, &c_enc));
    }
    std::vector<uint8_t> encoded;
    JXL_RETURN_IF_ERROR(Encode(*io, c_enc, bits, in_filename, &encoded, pool));
    JXL_RETURN_IF_ERROR(WriteFile(in_filename, encoded));
    std::vector<std::string> arguments = compress_args_;
    arguments.push_back(in_filename);
    arguments.push_back(encoded_filename);
    JXL_RETURN_IF_ERROR(ReportCodecRunningTime(
        [&, this] {
          return RunCommand(compress_command_, arguments, custom_args->quiet);
        },
        encoded_filename, speed_stats));
    return ReadFile(encoded_filename, compressed);
  }

  Status Decompress(const std::string& filename,
                    const Span<const uint8_t> compressed, ThreadPool* pool,
                    CodecInOut* io,
                    jpegxl::tools::SpeedStats* speed_stats) override {
    const std::string basename = GetBaseName(filename);
    TemporaryFile encoded_file(basename, extension_);
    TemporaryFile out_file(basename, custom_args->extension);
    std::string encoded_filename, out_filename;
    JXL_RETURN_IF_ERROR(encoded_file.GetFileName(&encoded_filename));
    JXL_RETURN_IF_ERROR(out_file.GetFileName(&out_filename));

    JXL_RETURN_IF_ERROR(WriteFile(encoded_filename, compressed));
    JXL_RETURN_IF_ERROR(ReportCodecRunningTime(
        [&, this] {
          return RunCommand(
              decompress_command_,
              std::vector<std::string>{encoded_filename, out_filename},
              custom_args->quiet);
        },
        out_filename, speed_stats));
    jxl::extras::ColorHints hints;
    if (!custom_args->colorspace.empty()) {
      hints.Add("color_space", custom_args->colorspace);
    }
    std::vector<uint8_t> encoded;
    JXL_RETURN_IF_ERROR(ReadFile(out_filename, &encoded));
    JXL_RETURN_IF_ERROR(
        jxl::SetFromBytes(jxl::Span<const uint8_t>(encoded), hints, io, pool));
    io->metadata.m.SetIntensityTarget(saved_intensity_target_);
    return true;
  }

 private:
  std::string extension_;
  std::string compress_command_;
  std::string decompress_command_;
  std::vector<std::string> compress_args_;
  int param_index_ = 0;
  int saved_intensity_target_ = 255;
};

}  // namespace

ImageCodec* CreateNewCustomCodec(const BenchmarkArgs& args) {
  return new CustomCodec(args);
}

}  // namespace tools
}  // namespace jpegxl

#else

namespace jpegxl {
namespace tools {

ImageCodec* CreateNewCustomCodec(const BenchmarkArgs& args) { return nullptr; }
Status AddCommandLineOptionsCustomCodec(BenchmarkArgs* args) { return true; }

}  // namespace tools
}  // namespace jpegxl

#endif  // _MSC_VER
