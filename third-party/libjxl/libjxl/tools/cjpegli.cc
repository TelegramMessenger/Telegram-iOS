// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include <vector>

#include "lib/extras/dec/decode.h"
#include "lib/extras/enc/jpegli.h"
#include "lib/extras/time.h"
#include "lib/jxl/base/printf_macros.h"
#include "lib/jxl/base/span.h"
#include "tools/args.h"
#include "tools/cmdline.h"
#include "tools/file_io.h"
#include "tools/speed_stats.h"

namespace jpegxl {
namespace tools {
namespace {

struct Args {
  void AddCommandLineOptions(CommandLineParser* cmdline) {
    std::string input_help("the input can be ");
    if (jxl::extras::CanDecode(jxl::extras::Codec::kPNG)) {
      input_help.append("PNG, APNG, ");
    }
    if (jxl::extras::CanDecode(jxl::extras::Codec::kGIF)) {
      input_help.append("GIF, ");
    }
    if (jxl::extras::CanDecode(jxl::extras::Codec::kEXR)) {
      input_help.append("EXR, ");
    }
    input_help.append("PPM, PFM, or PGX");
    cmdline->AddPositionalOption("INPUT", /* required = */ true, input_help,
                                 &file_in);
    cmdline->AddPositionalOption("OUTPUT", /* required = */ true,
                                 "the compressed JPG output file", &file_out);

    cmdline->AddOptionFlag('\0', "disable_output",
                           "No output file will be written (for benchmarking)",
                           &disable_output, &SetBooleanTrue, 1);

    cmdline->AddOptionValue(
        'x', "dec-hints", "key=value",
        "color_space indicates the ColorEncoding, see Description();\n"
        "    icc_pathname refers to a binary file containing an ICC profile.",
        &color_hints_proxy, &ParseAndAppendKeyValue<ColorHintsProxy>, 1);

    opt_distance_id = cmdline->AddOptionValue(
        'd', "distance", "maxError",
        "Max. butteraugli distance, lower = higher quality.\n"
        "    1.0 = visually lossless (default).\n"
        "    Recommended range: 0.5 .. 3.0. Allowed range: 0.0 ... 25.0.\n"
        "    Mutually exclusive with --quality and --target_size.",
        &settings.distance, &ParseFloat);

    opt_quality_id = cmdline->AddOptionValue(
        'q', "quality", "QUALITY",
        "Quality setting (is remapped to --distance)."
        "    Default is quality 90.\n"
        "    Quality values roughly match libjpeg quality.\n"
        "    Recommended range: 68 .. 96. Allowed range: 1 .. 100.\n"
        "    Mutually exclusive with --distance and --target_size.",
        &quality, &ParseSigned);

    cmdline->AddOptionValue('\0', "chroma_subsampling", "444|440|422|420",
                            "Chroma subsampling setting.",
                            &settings.chroma_subsampling, &ParseString);

    cmdline->AddOptionValue(
        'p', "progressive_level", "N",
        "Progressive level setting. Range: 0 .. 2.\n"
        "    Default: 2. Higher number is more scans, 0 means sequential.",
        &settings.progressive_level, &ParseSigned);

    cmdline->AddOptionFlag('\0', "xyb", "Convert to XYB colorspace",
                           &settings.xyb, &SetBooleanTrue, 1);

    cmdline->AddOptionFlag(
        '\0', "std_quant",
        "Use quantization tables based on Annex K of the JPEG standard.",
        &settings.use_std_quant_tables, &SetBooleanTrue, 1);

    cmdline->AddOptionFlag(
        '\0', "noadaptive_quantization", "Disable adaptive quantization.",
        &settings.use_adaptive_quantization, &SetBooleanFalse, 1);

    cmdline->AddOptionFlag(
        '\0', "fixed_code",
        "Disable Huffman code optimization. Must be used together with -p 0.",
        &settings.optimize_coding, &SetBooleanFalse, 1);

    cmdline->AddOptionValue(
        '\0', "target_size", "N",
        "If non-zero, set target size in bytes. This is useful for image \n"
        "    quality comparisons, but makes encoding speed up to 20x slower.\n"
        "    Mutually exclusive with --distance and --quality.",
        &settings.target_size, &ParseUnsigned, 2);

    cmdline->AddOptionValue('\0', "num_reps", "N",
                            "How many times to compress. (For benchmarking).",
                            &num_reps, &ParseUnsigned, 1);

    cmdline->AddOptionFlag('\0', "quiet", "Suppress informative output", &quiet,
                           &SetBooleanTrue, 1);

    cmdline->AddOptionFlag(
        'v', "verbose",
        "Verbose output; can be repeated, also applies to help (!).", &verbose,
        &SetBooleanTrue);
  }

  const char* file_in = nullptr;
  const char* file_out = nullptr;
  bool disable_output = false;
  ColorHintsProxy color_hints_proxy;
  jxl::extras::JpegSettings settings;
  int quality = 90;
  size_t num_reps = 1;
  bool quiet = false;
  bool verbose = false;
  // References (ids) of specific options to check if they were matched.
  CommandLineParser::OptionId opt_distance_id = -1;
  CommandLineParser::OptionId opt_quality_id = -1;
};

bool ValidateArgs(const Args& args) {
  const jxl::extras::JpegSettings& settings = args.settings;
  if (settings.distance < 0.0 || settings.distance > 25.0) {
    fprintf(stderr, "Invalid --distance argument\n");
    return false;
  }
  if (args.quality <= 0 || args.quality > 100) {
    fprintf(stderr, "Invalid --quality argument\n");
    return false;
  }
  std::string cs = settings.chroma_subsampling;
  if (!cs.empty() && cs != "444" && cs != "440" && cs != "422" && cs != "420") {
    fprintf(stderr, "Invalid --chroma_subsampling argument\n");
    return false;
  }
  if (settings.progressive_level < 0 || settings.progressive_level > 2) {
    fprintf(stderr, "Invalid --progressive_level argument\n");
    return false;
  }
  if (settings.progressive_level > 0 && !settings.optimize_coding) {
    fprintf(stderr, "--fixed_code must be used together with -p 0\n");
    return false;
  }
  return true;
}

bool SetDistance(const Args& args, const CommandLineParser& cmdline,
                 jxl::extras::JpegSettings* settings) {
  bool distance_set = cmdline.GetOption(args.opt_distance_id)->matched();
  bool quality_set = cmdline.GetOption(args.opt_quality_id)->matched();
  int num_quality_settings = (distance_set ? 1 : 0) + (quality_set ? 1 : 0) +
                             (args.settings.target_size > 0 ? 1 : 0);
  if (num_quality_settings > 1) {
    fprintf(
        stderr,
        "Only one of --distance, --quality, or --target_size can be set.\n");
    return false;
  }
  if (quality_set) {
    settings->quality = args.quality;
  }
  return true;
}

int CJpegliMain(int argc, const char* argv[]) {
  Args args;
  CommandLineParser cmdline;
  args.AddCommandLineOptions(&cmdline);

  if (!cmdline.Parse(argc, const_cast<const char**>(argv))) {
    // Parse already printed the actual error cause.
    fprintf(stderr, "Use '%s -h' for more information.\n", argv[0]);
    return EXIT_FAILURE;
  }

  if (cmdline.HelpFlagPassed() || !args.file_in) {
    cmdline.PrintHelp();
    return EXIT_SUCCESS;
  }

  if (!args.file_out && !args.disable_output) {
    fprintf(stderr,
            "No output file specified and --disable_output flag not passed.\n");
    return EXIT_FAILURE;
  }

  if (args.disable_output && !args.quiet) {
    fprintf(stderr,
            "Encoding will be performed, but the result will be discarded.\n");
  }

  std::vector<uint8_t> input_bytes;
  if (!ReadFile(args.file_in, &input_bytes)) {
    fprintf(stderr, "Failed to read input image %s\n", args.file_in);
    return EXIT_FAILURE;
  }

  jxl::extras::PackedPixelFile ppf;
  if (!jxl::extras::DecodeBytes(jxl::Span<const uint8_t>(input_bytes),
                                args.color_hints_proxy.target, &ppf)) {
    fprintf(stderr, "Failed to decode input image %s\n", args.file_in);
    return EXIT_FAILURE;
  }

  if (!args.quiet) {
    fprintf(stderr, "Read %ux%u image, %" PRIuS " bytes.\n", ppf.info.xsize,
            ppf.info.ysize, input_bytes.size());
  }

  if (!ValidateArgs(args) || !SetDistance(args, cmdline, &args.settings)) {
    return EXIT_FAILURE;
  }

  if (!args.quiet) {
    const jxl::extras::JpegSettings& s = args.settings;
    fprintf(stderr, "Encoding [%s%s d%.3f%s %sAQ p%d %s]\n",
            s.xyb ? "XYB" : "YUV", s.chroma_subsampling.c_str(), s.distance,
            s.use_std_quant_tables ? " StdQuant" : "",
            s.use_adaptive_quantization ? "" : "no", s.progressive_level,
            s.optimize_coding ? "OPT" : "FIX");
  }

  jpegxl::tools::SpeedStats stats;
  std::vector<uint8_t> jpeg_bytes;
  for (size_t num_rep = 0; num_rep < args.num_reps; ++num_rep) {
    const double t0 = jxl::Now();
    if (!jxl::extras::EncodeJpeg(ppf, args.settings, nullptr, &jpeg_bytes)) {
      fprintf(stderr, "jpegli encoding failed\n");
      return EXIT_FAILURE;
    }
    const double t1 = jxl::Now();
    stats.NotifyElapsed(t1 - t0);
    stats.SetImageSize(ppf.info.xsize, ppf.info.ysize);
  }

  if (args.file_out && !args.disable_output) {
    if (!WriteFile(args.file_out, jpeg_bytes)) {
      fprintf(stderr, "Could not write jpeg to %s\n", args.file_out);
      return EXIT_FAILURE;
    }
  }
  if (!args.quiet) {
    fprintf(stderr, "Compressed to %" PRIuS " bytes ", jpeg_bytes.size());
    const size_t num_pixels = ppf.info.xsize * ppf.info.ysize;
    const double bpp =
        static_cast<double>(jpeg_bytes.size() * jxl::kBitsPerByte) / num_pixels;
    fprintf(stderr, "(%.3f bpp).\n", bpp);
    stats.Print(1);
  }
  return EXIT_SUCCESS;
}

}  // namespace
}  // namespace tools
}  // namespace jpegxl

int main(int argc, const char** argv) {
  return jpegxl::tools::CJpegliMain(argc, argv);
}
