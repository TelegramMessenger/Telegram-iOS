// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef TOOLS_BENCHMARK_BENCHMARK_ARGS_H_
#define TOOLS_BENCHMARK_BENCHMARK_ARGS_H_

// Command line parsing and arguments for benchmark_xl

#include <stddef.h>

#include <algorithm>
#include <deque>
#include <string>
#include <vector>

#include "lib/extras/dec/color_hints.h"
#include "lib/jxl/base/override.h"
#include "lib/jxl/base/status.h"
#include "lib/jxl/butteraugli/butteraugli.h"
#include "lib/jxl/color_encoding_internal.h"
#include "tools/args.h"
#include "tools/cmdline.h"

namespace jpegxl {
namespace tools {

using ::jxl::ColorEncoding;
using ::jxl::Override;
using ::jxl::Status;

std::vector<std::string> SplitString(const std::string& s, char c);

int ParseIntParam(const std::string& param, int lower_bound, int upper_bound);

struct BenchmarkArgs {
  using OptionId = jpegxl::tools::CommandLineParser::OptionId;

  void AddFlag(bool* field, const char* longName, const char* help,
               bool defaultValue) {
    const char* noName = RememberString_(std::string("no") + longName);
    cmdline.AddOptionFlag('\0', longName, nullptr, field,
                          &jpegxl::tools::SetBooleanTrue);
    cmdline.AddOptionFlag('\0', noName, help, field,
                          &jpegxl::tools::SetBooleanFalse);
    *field = defaultValue;
  }

  OptionId AddOverride(Override* field, const char* longName,
                       const char* help) {
    OptionId result = cmdline.AddOptionValue('\0', longName, "0|1", help, field,
                                             &jpegxl::tools::ParseOverride);
    *field = Override::kDefault;
    return result;
  }

  OptionId AddString(std::string* field, const char* longName, const char* help,
                     const std::string& defaultValue = "") {
    OptionId result = cmdline.AddOptionValue(
        '\0', longName, "<string>", help, field, &jpegxl::tools::ParseString);
    *field = defaultValue;
    return result;
  }

  OptionId AddFloat(float* field, const char* longName, const char* help,
                    float defaultValue) {
    OptionId result = cmdline.AddOptionValue('\0', longName, "<scalar>", help,
                                             field, &jpegxl::tools::ParseFloat);
    *field = defaultValue;
    return result;
  }

  OptionId AddDouble(double* field, const char* longName, const char* help,
                     double defaultValue) {
    OptionId result = cmdline.AddOptionValue(
        '\0', longName, "<scalar>", help, field, &jpegxl::tools::ParseDouble);
    *field = defaultValue;
    return result;
  }

  OptionId AddSigned(int* field, const char* longName, const char* help,
                     int defaultValue) {
    OptionId result = cmdline.AddOptionValue(
        '\0', longName, "<integer>", help, field, &jpegxl::tools::ParseSigned);
    *field = defaultValue;
    return result;
  }

  OptionId AddUnsigned(size_t* field, const char* longName, const char* help,
                       size_t defaultValue) {
    OptionId result =
        cmdline.AddOptionValue('\0', longName, "<unsigned>", help, field,
                               &jpegxl::tools::ParseUnsigned);
    *field = defaultValue;
    return result;
  }

  Status AddCommandLineOptions();

  Status ValidateArgs();

  bool Parse(int argc, const char** argv) { return cmdline.Parse(argc, argv); }

  void PrintHelp() const { cmdline.PrintHelp(); }

  std::string input;
  std::string codec;
  bool print_details;
  bool print_details_csv;
  bool print_more_stats;
  bool print_distance_percentiles;
  bool silent_errors;
  bool save_compressed;
  bool save_decompressed;
  std::string output_extension;    // see CodecFromPath
  std::string output_description;  // see ParseDescription
  ColorEncoding output_encoding;   // determined by output_description

  bool decode_only;
  bool skip_butteraugli;

  float intensity_target;

  std::string color_hints_string;
  jxl::extras::ColorHints color_hints;

  size_t override_bitdepth;

  double mul_output;
  double heatmap_good;
  double heatmap_bad;

  bool save_heatmap;
  bool write_html_report;
  bool html_report_self_contained;
  bool html_report_use_decompressed;
  bool html_report_add_heatmap;
  bool markdown;
  bool more_columns;

  std::string originals_url;
  std::string output_dir;

  int num_threads;
  int inner_threads;
  size_t decode_reps;
  size_t encode_reps;

  std::string sample_tmp_dir;

  int num_samples;
  int sample_dimensions;

  double error_pnorm;
  bool show_progress;

  std::string extra_metrics;

  jpegxl::tools::CommandLineParser cmdline;

 private:
  const char* RememberString_(const std::string& text) {
    const char* data = text.c_str();
    std::vector<char> copy(data, data + text.size() + 1);
    string_pool_.push_back(copy);
    return string_pool_.back().data();
  }

  // A memory pool with stable addresses for strings to provide stable
  // const char pointers to cmdline.h for dynamic help/name strings.
  std::deque<std::vector<char>> string_pool_;
};

// Returns singleton
BenchmarkArgs* Args();

}  // namespace tools
}  // namespace jpegxl

#endif  // TOOLS_BENCHMARK_BENCHMARK_ARGS_H_
