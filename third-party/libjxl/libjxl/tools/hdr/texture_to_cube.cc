// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include <stdio.h>
#include <stdlib.h>

#include "lib/extras/codec.h"
#include "lib/jxl/image_bundle.h"
#include "tools/args.h"
#include "tools/cmdline.h"
#include "tools/thread_pool_internal.h"

int main(int argc, const char** argv) {
  jpegxl::tools::ThreadPoolInternal pool;

  jpegxl::tools::CommandLineParser parser;
  const char* input_filename = nullptr;
  auto input_filename_option = parser.AddPositionalOption(
      "input", true, "input image", &input_filename, 0);
  const char* output_filename = nullptr;
  auto output_filename_option = parser.AddPositionalOption(
      "output", true, "output Cube LUT", &output_filename, 0);

  if (!parser.Parse(argc, argv)) {
    fprintf(stderr, "See -h for help.\n");
    return EXIT_FAILURE;
  }

  if (parser.HelpFlagPassed()) {
    parser.PrintHelp();
    return EXIT_SUCCESS;
  }

  if (!parser.GetOption(input_filename_option)->matched()) {
    fprintf(stderr, "Missing input filename.\nSee -h for help.\n");
    return EXIT_FAILURE;
  }
  if (!parser.GetOption(output_filename_option)->matched()) {
    fprintf(stderr, "Missing output filename.\nSee -h for help.\n");
    return EXIT_FAILURE;
  }

  jxl::CodecInOut image;
  std::vector<uint8_t> encoded;
  JXL_CHECK(jpegxl::tools::ReadFile(input_filename, &encoded));
  JXL_CHECK(jxl::SetFromBytes(jxl::Span<const uint8_t>(encoded),
                              jxl::extras::ColorHints(), &image, &pool));

  JXL_CHECK(image.xsize() == image.ysize() * image.ysize());
  const unsigned N = image.ysize();

  FILE* const output = fopen(output_filename, "wb");
  JXL_CHECK(output);

  fprintf(output, "# Created by libjxl\n");
  fprintf(output, "LUT_3D_SIZE %u\n", N);
  fprintf(output, "DOMAIN_MIN 0.0 0.0 0.0\nDOMAIN_MAX 1.0 1.0 1.0\n\n");

  for (size_t b = 0; b < N; ++b) {
    for (size_t g = 0; g < N; ++g) {
      const size_t y = g;
      const float* const JXL_RESTRICT rows[3] = {
          image.Main().color()->ConstPlaneRow(0, y) + N * b,
          image.Main().color()->ConstPlaneRow(1, y) + N * b,
          image.Main().color()->ConstPlaneRow(2, y) + N * b};
      for (size_t r = 0; r < N; ++r) {
        const size_t x = r;
        fprintf(output, "%.6f %.6f %.6f\n", rows[0][x], rows[1][x], rows[2][x]);
      }
    }
  }
}
