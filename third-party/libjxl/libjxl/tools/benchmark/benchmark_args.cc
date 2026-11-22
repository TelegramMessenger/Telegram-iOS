// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "tools/benchmark/benchmark_args.h"

#include <stddef.h>
#include <stdlib.h>

#include <algorithm>
#include <string>
#include <vector>

#include "lib/extras/codec.h"
#include "lib/extras/dec/color_description.h"
#include "lib/jxl/base/status.h"
#include "lib/jxl/color_encoding_internal.h"
#include "lib/jxl/color_management.h"
#include "tools/benchmark/benchmark_codec_custom.h"  // for AddCommand..
#include "tools/benchmark/benchmark_codec_jpeg.h"  // for AddCommand..
#include "tools/benchmark/benchmark_codec_jxl.h"
#include "tools/benchmark/benchmark_codec_png.h"

#ifdef BENCHMARK_WEBP
#include "tools/benchmark/benchmark_codec_webp.h"
#endif  // BENCHMARK_WEBP

#ifdef BENCHMARK_AVIF
#include "tools/benchmark/benchmark_codec_avif.h"
#endif  // BENCHMARK_AVIF

namespace jpegxl {
namespace tools {

std::vector<std::string> SplitString(const std::string& s, char c) {
  std::vector<std::string> result;
  size_t pos = 0;
  for (size_t i = 0; i <= s.size(); i++) {
    if (i == s.size() || s[i] == c) {
      result.push_back(s.substr(pos, i - pos));
      pos = i + 1;
    }
  }
  return result;
}

int ParseIntParam(const std::string& param, int lower_bound, int upper_bound) {
  int val = strtol(param.substr(1).c_str(), nullptr, 10);
  JXL_CHECK(val >= lower_bound && val <= upper_bound);
  return val;
}

BenchmarkArgs* Args() {
  static BenchmarkArgs args;
  return &args;
}

Status BenchmarkArgs::AddCommandLineOptions() {
  AddString(&input, "input", "File or file pattern matching input files.");
  AddString(&codec, "codec",
            "Comma separated list of image codec descriptions to benchmark.",
            "jxl");
  AddFlag(&print_details, "print_details",
          "Prints size and distortion for each image. Not safe for "
          "concurrent benchmark runs.",
          false);
  AddFlag(&print_details_csv, "print_details_csv",
          "When print_details is used, print as CSV.", false);
  AddString(&extra_metrics, "extra_metrics",
            "Extra metrics to be computed. Only displayed with --print_details "
            "or --print_details_csv. Comma-separated list of NAME:COMMAND "
            "pairs; COMMAND is invoked with the original image as the first "
            "argument, the decompressed image as a second argument, and the "
            "name of the file where to write the metric value (as a single "
            "floating point number) as the third argument.",
            "");
  AddFlag(
      &print_more_stats, "print_more_stats",
      "Prints codec-specific stats. Not safe for concurrent benchmark runs.",
      false);
  AddFlag(&print_distance_percentiles, "print_distance_percentiles",
          "Prints distance percentiles for the corpus. Not safe for "
          "concurrent benchmark runs.",
          false);
  AddFlag(&silent_errors, "silent_errors",
          "If true, doesn't print error messages on compression or"
          " decompression errors. Errors counts are still visible in the"
          " 'Errors' column of the result table. Please note that depending"
          " depending on the JXL build settings, error messages and asserts"
          " from within the codec may be printed irrespective of this flag"
          " anyway, use release build to ensure no messages.",
          false);
  AddFlag(&save_compressed, "save_compressed",
          "Saves the compressed files for each input image and each codec.",
          false);
  AddFlag(&save_decompressed, "save_decompressed",
          "Saves the decompressed files as PNG for each input image "
          "and each codec.",
          false);
  AddString(&output_extension, "output_extension",
            "Extension (starting with dot) to use for saving output images.",
            ".png");
  AddString(&output_description, "output_description",
            "Color encoding (see ParseDescription; e.g. RGB_D65_SRG_Rel_709) "
            "for saving output images, "
            " defaults to sRGB.");

  AddFloat(&intensity_target, "intensity_target",
           "Intended viewing intensity target in nits. Defaults to 255 for "
           "SDR images, 4000 for HDR images (when the input image uses PQ or "
           "HLG transfer function)",
           0);

  AddString(&color_hints_string, "dec-hints",
            "Color encoding hints for the input images to encoder. Comma "
            "separated key=value pairs. The key color_space indicates "
            "ColorEncoding (see ParseDescription; e.g. RGB_D65_SRG_Rel_709) "
            "for input images without color encoding (such as PNM)");

  AddUnsigned(
      &override_bitdepth, "override_bitdepth",
      "If nonzero, store the given bit depth in the JPEG XL file metadata"
      " (1-32), instead of using the bit depth from the original input"
      " image.",
      0);

  AddDouble(&mul_output, "mul_output",
            "If nonzero, multiplies linear sRGB by this and clamps to 255",
            0.0);
  AddFlag(&save_heatmap, "save_heatmap", "Saves the heatmap images.", true);
  AddDouble(&heatmap_good, "heatmap_good",
            "If greater than zero, use this as the good "
            "threshold for creating heatmap images.",
            0.0);
  AddDouble(&heatmap_bad, "heatmap_bad",
            "If greater than zero, use this as the bad "
            "threshold for creating heatmap images.",
            0.0);

  AddFlag(&write_html_report, "write_html_report",
          "Creates an html report with original and compressed images.", false);
  AddFlag(&html_report_self_contained, "html_report_self_contained",
          "Base64-encode the images in the HTML report rather than use "
          "external file names. May cause very large HTML data size.",
          false);
  AddFlag(&html_report_use_decompressed, "html_report_use_decompressed",
          "Show the compressed image as decompressed to --output_extension.",
          true);
  AddFlag(&html_report_add_heatmap, "html_report_add_heatmap",
          "Add heatmaps to the image comparisons.", false);

  AddFlag(
      &markdown, "markdown",
      "Adds formatting around ASCII table to render correctly in Markdown based"
      " interfaces",
      true);

  AddFlag(&more_columns, "more_columns", "Print extra columns in the table",
          false);

  AddString(&originals_url, "originals_url",
            "Url prefix to serve original images from in the html report.");
  AddString(&output_dir, "output_dir",
            "If not empty, save compressed and decompressed "
            "images here.");

  AddSigned(&num_threads, "num_threads",
            "The number of threads for concurrent benchmarking. Defaults to "
            "1 thread per CPU core (if negative).",
            -1);
  AddSigned(&inner_threads, "inner_threads",
            "The number of extra threads per task. "
            "Defaults to occupy cores (if negative).",
            -1);
  AddUnsigned(&encode_reps, "encode_reps",
              "How many times to encode (>1 for more precise measurements). "
              "Defaults to 1.",
              1);
  AddUnsigned(&decode_reps, "decode_reps",
              "How many times to decode (>1 for more precise measurements). "
              "Defaults to 1.",
              1);

  AddString(&sample_tmp_dir, "sample_tmp_dir",
            "Directory to put samples from input images.");

  AddSigned(&num_samples, "num_samples", "How many sample areas to take.", 0);
  AddSigned(&sample_dimensions, "sample_dimensions",
            "How big areas to sample from the input.", 64);

  AddDouble(&error_pnorm, "error_pnorm",
            "smallest p norm for pooling butteraugli values", 3.0);

  AddFlag(&show_progress, "show_progress",
          "Show activity dots per completed file during benchmark.", false);

  AddFlag(&skip_butteraugli, "skip_butteraugli",
          "If true, doesn't compute distance metrics, only compression and"
          " decompression speed and size. Distance numbers shown in the"
          " table are invalid.",
          false);

  AddFlag(
      &decode_only, "decode_only",
      "If true, only decodes, and the input files must be compressed with a "
      "compatible format for the given codec(s). Only measures decompression "
      "speed and sizes, and can only use a single set of compatible decoders. "
      "Distance numbers and compression speeds shown in the table are invalid.",
      false);

  if (!AddCommandLineOptionsCustomCodec(this)) return false;
  if (!AddCommandLineOptionsJxlCodec(this)) return false;
  if (!AddCommandLineOptionsJPEGCodec(this)) return false;
  if (!AddCommandLineOptionsPNGCodec(this)) return false;

#ifdef BENCHMARK_WEBP
  if (!AddCommandLineOptionsWebPCodec(this)) return false;
#endif  // BENCHMARK_WEBP
#ifdef BENCHMARK_AVIF
  if (!AddCommandLineOptionsAvifCodec(this)) return false;
#endif  // BENCHMARK_AVIF

  return true;
}

Status BenchmarkArgs::ValidateArgs() {
  if (input.empty()) {
    fprintf(stderr, "Missing --input filename(s).\n");
    return false;
  }
  if (jxl::extras::CodecFromPath(output_extension) ==
      jxl::extras::Codec::kUnknown) {
    JXL_WARNING("Unrecognized output_extension %s, try .png",
                output_extension.c_str());
    return false;  // already warned
  }

  // If empty, don't do anything; callers must only use output_encoding if
  // output_description is not empty.
  if (!output_description.empty()) {
    // Validate, but also create the profile (only needs to happen once).
    JxlColorEncoding output_encoding_external;
    if (!jxl::ParseDescription(output_description, &output_encoding_external)) {
      JXL_WARNING("Unrecognized output_description %s, try RGB_D65_SRG_Rel_Lin",
                  output_description.c_str());
      return false;  // already warned
    }
    JXL_RETURN_IF_ERROR(jxl::ConvertExternalToInternalColorEncoding(
        output_encoding_external, &output_encoding));
    JXL_RETURN_IF_ERROR(output_encoding.CreateICC());
  }

  JXL_RETURN_IF_ERROR(ValidateArgsJxlCodec(this));

  if (print_details_csv) print_details = true;

  if (override_bitdepth > 32) {
    return JXL_FAILURE("override_bitdepth must be <= 32");
  }

  if (!color_hints_string.empty()) {
    std::vector<std::string> hints = SplitString(color_hints_string, ',');
    for (const auto& hint : hints) {
      std::vector<std::string> kv = SplitString(hint, '=');
      if (kv.size() != 2) {
        return JXL_FAILURE(
            "dec-hints key value pairs must have the form 'key=value'");
      }
      color_hints.Add(kv[0], kv[1]);
    }
  }

  return true;
}

}  // namespace tools
}  // namespace jpegxl
