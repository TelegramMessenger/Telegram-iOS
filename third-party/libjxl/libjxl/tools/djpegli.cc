// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include <string>
#include <vector>

#include "lib/extras/dec/jpegli.h"
#include "lib/extras/enc/apng.h"
#include "lib/extras/enc/encode.h"
#include "lib/extras/time.h"
#include "lib/jxl/base/printf_macros.h"
#include "tools/cmdline.h"
#include "tools/file_io.h"
#include "tools/speed_stats.h"

namespace jpegxl {
namespace tools {
namespace {

struct Args {
  void AddCommandLineOptions(CommandLineParser* cmdline) {
    std::string output_help("The output can be ");
    if (jxl::extras::GetAPNGEncoder()) {
      output_help.append("PNG, ");
    }
    output_help.append("PFM or PPM/PGM/PNM");
    cmdline->AddPositionalOption("INPUT", /* required = */ true,
                                 "The JPG input file.", &file_in);

    cmdline->AddPositionalOption("OUTPUT", /* required = */ true, output_help,
                                 &file_out);
    cmdline->AddOptionFlag('\0', "disable_output",
                           "No output file will be written (for benchmarking)",
                           &disable_output, &SetBooleanTrue);

    cmdline->AddOptionValue('\0', "bitdepth", "8|16",
                            "Sets the output bitdepth for integer based "
                            "formats, can be 8 (default) "
                            "or 16. Has no impact on PFM output.",
                            &bitdepth, &ParseUnsigned);

    cmdline->AddOptionValue('\0', "num_reps", "N",
                            "Sets the number of times to decompress the image. "
                            "Used for benchmarking, the default is 1.",
                            &num_reps, &ParseUnsigned);

    cmdline->AddOptionFlag('\0', "quiet", "Silence output (except for errors).",
                           &quiet, &SetBooleanTrue);
  }

  const char* file_in = nullptr;
  const char* file_out = nullptr;
  bool disable_output = false;
  size_t bitdepth = 8;
  size_t num_reps = 1;
  bool quiet = false;
};

bool ValidateArgs(const Args& args) {
  if (args.bitdepth != 8 && args.bitdepth != 16) {
    fprintf(stderr, "Invalid --bitdepth argument\n");
    return false;
  }
  return true;
}

void SetDecompressParams(const Args& args, const std::string& extension,
                         jxl::extras::JpegDecompressParams* params) {
  if (extension == ".pfm") {
    params->output_data_type = JXL_TYPE_FLOAT;
    params->output_endianness = JXL_BIG_ENDIAN;
  } else if (args.bitdepth == 16) {
    params->output_data_type = JXL_TYPE_UINT16;
    params->output_endianness = JXL_BIG_ENDIAN;
  }
  if (extension == ".pgm") {
    params->force_grayscale = true;
  } else if (extension == ".ppm") {
    params->force_rgb = true;
  }
}

int DJpegliMain(int argc, const char* argv[]) {
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
            "Decoding will be performed, but the result will be discarded.\n");
  }

  if (!ValidateArgs(args)) {
    return EXIT_FAILURE;
  }

  std::vector<uint8_t> jpeg_bytes;
  if (!ReadFile(args.file_in, &jpeg_bytes)) {
    fprintf(stderr, "Failed to read input image %s\n", args.file_in);
    return EXIT_FAILURE;
  }

  if (!args.quiet) {
    fprintf(stderr, "Read %" PRIuS " compressed bytes.\n", jpeg_bytes.size());
  }

  std::string filename_out;
  std::string extension;
  if (args.file_out) {
    filename_out = std::string(args.file_out);
    size_t pos = filename_out.find_last_of('.');
    if (pos >= filename_out.size()) {
      fprintf(stderr, "Unrecognized output extension.\n");
      return EXIT_FAILURE;
    }
    extension = filename_out.substr(pos);
  }

  jxl::extras::JpegDecompressParams dparams;
  SetDecompressParams(args, extension, &dparams);

  jxl::extras::PackedPixelFile ppf;
  jpegxl::tools::SpeedStats stats;
  for (size_t num_rep = 0; num_rep < args.num_reps; ++num_rep) {
    const double t0 = jxl::Now();
    if (!jxl::extras::DecodeJpeg(jpeg_bytes, dparams, nullptr, &ppf)) {
      fprintf(stderr, "jpegli decoding failed\n");
      return EXIT_FAILURE;
    }
    const double t1 = jxl::Now();
    stats.NotifyElapsed(t1 - t0);
    stats.SetImageSize(ppf.info.xsize, ppf.info.ysize);
  }

  if (!args.quiet) {
    stats.Print(1);
  }

  if (args.disable_output) {
    return EXIT_SUCCESS;
  }

  if (extension == ".pnm") {
    extension = ppf.info.num_color_channels == 3 ? ".ppm" : ".pgm";
  }

  std::unique_ptr<jxl::extras::Encoder> encoder =
      jxl::extras::Encoder::FromExtension(extension);
  if (encoder == nullptr) {
    fprintf(stderr, "Can't decode to the file extension '%s'\n",
            extension.c_str());
    return EXIT_FAILURE;
  }
  jxl::extras::EncodedImage encoded_image;
  if (!encoder->Encode(ppf, &encoded_image) ||
      encoded_image.bitstreams.empty()) {
    fprintf(stderr, "Encode failed\n");
    return EXIT_FAILURE;
  }
  if (!WriteFile(filename_out, encoded_image.bitstreams[0])) {
    fprintf(stderr, "Failed to write output file %s\n", filename_out.c_str());
    return EXIT_FAILURE;
  }

  return EXIT_SUCCESS;
}

}  // namespace
}  // namespace tools
}  // namespace jpegxl

int main(int argc, const char* argv[]) {
  return jpegxl::tools::DJpegliMain(argc, argv);
}
