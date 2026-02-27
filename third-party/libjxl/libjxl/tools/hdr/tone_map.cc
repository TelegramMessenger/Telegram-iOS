// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include <stdio.h>
#include <stdlib.h>

#include "lib/extras/codec.h"
#include "lib/extras/tone_mapping.h"
#include "lib/jxl/enc_color_management.h"
#include "tools/args.h"
#include "tools/cmdline.h"
#include "tools/file_io.h"
#include "tools/hdr/image_utils.h"
#include "tools/thread_pool_internal.h"

int main(int argc, const char** argv) {
  jpegxl::tools::ThreadPoolInternal pool;

  jpegxl::tools::CommandLineParser parser;
  float max_nits = 0;
  parser.AddOptionValue('m', "max_nits", "nits",
                        "maximum luminance in the image", &max_nits,
                        &jpegxl::tools::ParseFloat, 0);
  float target_nits = 0;
  auto target_nits_option = parser.AddOptionValue(
      't', "target_nits", "nits",
      "peak luminance of the display for which to tone map", &target_nits,
      &jpegxl::tools::ParseFloat, 0);
  float preserve_saturation = .1f;
  parser.AddOptionValue(
      's', "preserve_saturation", "0..1",
      "to what extent to try and preserve saturation over luminance",
      &preserve_saturation, &jpegxl::tools::ParseFloat, 0);
  bool pq = false;
  parser.AddOptionFlag('p', "pq",
                       "write the output with absolute luminance using PQ", &pq,
                       &jpegxl::tools::SetBooleanTrue, 0);
  const char* input_filename = nullptr;
  auto input_filename_option = parser.AddPositionalOption(
      "input", true, "input image", &input_filename, 0);
  const char* output_filename = nullptr;
  auto output_filename_option = parser.AddPositionalOption(
      "output", true, "output image", &output_filename, 0);

  if (!parser.Parse(argc, argv)) {
    fprintf(stderr, "See -h for help.\n");
    return EXIT_FAILURE;
  }

  if (parser.HelpFlagPassed()) {
    parser.PrintHelp();
    return EXIT_SUCCESS;
  }

  if (!parser.GetOption(target_nits_option)->matched()) {
    fprintf(stderr,
            "Missing required argument --target_nits.\nSee -h for help.\n");
    return EXIT_FAILURE;
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
  jxl::extras::ColorHints color_hints;
  color_hints.Add("color_space", "RGB_D65_202_Rel_PeQ");
  std::vector<uint8_t> encoded;
  JXL_CHECK(jpegxl::tools::ReadFile(input_filename, &encoded));
  JXL_CHECK(jxl::SetFromBytes(jxl::Span<const uint8_t>(encoded), color_hints,
                              &image, &pool));
  if (max_nits > 0) {
    image.metadata.m.SetIntensityTarget(max_nits);
  }
  JXL_CHECK(jxl::ToneMapTo({0, target_nits}, &image, &pool));
  JXL_CHECK(jxl::GamutMap(&image, preserve_saturation, &pool));

  jxl::ColorEncoding c_out = image.metadata.m.color_encoding;
  if (pq) {
    c_out.tf.SetTransferFunction(jxl::TransferFunction::kPQ);
  } else {
    c_out.tf.SetTransferFunction(jxl::TransferFunction::kSRGB);
  }

  if (jxl::extras::CodecFromPath(output_filename) == jxl::extras::Codec::kEXR) {
    c_out.tf.SetTransferFunction(jxl::TransferFunction::kLinear);
    image.metadata.m.SetFloat16Samples();
  }

  JXL_CHECK(c_out.CreateICC());
  JXL_CHECK(jpegxl::tools::TransformCodecInOutTo(image, c_out, &pool));
  image.metadata.m.color_encoding = c_out;
  JXL_CHECK(jxl::Encode(image, output_filename, &encoded, &pool));
  JXL_CHECK(jpegxl::tools::WriteFile(output_filename, encoded));
}
