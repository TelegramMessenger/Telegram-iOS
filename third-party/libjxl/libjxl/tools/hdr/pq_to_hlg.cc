// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include <stdio.h>
#include <stdlib.h>

#include "lib/extras/codec.h"
#include "lib/extras/hlg.h"
#include "lib/extras/tone_mapping.h"
#include "lib/jxl/enc_color_management.h"
#include "tools/args.h"
#include "tools/cmdline.h"
#include "tools/hdr/image_utils.h"
#include "tools/thread_pool_internal.h"

int main(int argc, const char** argv) {
  jpegxl::tools::ThreadPoolInternal pool;

  jpegxl::tools::CommandLineParser parser;
  float max_nits = 0;
  parser.AddOptionValue('m', "max_nits", "nits",
                        "maximum luminance in the image", &max_nits,
                        &jpegxl::tools::ParseFloat, 0);
  float preserve_saturation = .1f;
  parser.AddOptionValue(
      's', "preserve_saturation", "0..1",
      "to what extent to try and preserve saturation over luminance",
      &preserve_saturation, &jpegxl::tools::ParseFloat, 0);
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
  const jxl::Primaries original_primaries = image.Main().c_current().primaries;
  JXL_CHECK(jxl::ToneMapTo({0, 1000}, &image, &pool));
  JXL_CHECK(jxl::HlgInverseOOTF(&image.Main(), 1.2f, &pool));
  JXL_CHECK(jxl::GamutMap(&image, preserve_saturation, &pool));
  // Peak luminance at which the system gamma is 1, since we are now in scene
  // light, having applied the inverse OOTF ourselves to control the subsequent
  // gamut mapping instead of leaving it to JxlCms below.
  image.metadata.m.SetIntensityTarget(301);

  jxl::ColorEncoding hlg;
  hlg.SetColorSpace(jxl::ColorSpace::kRGB);
  hlg.primaries = original_primaries;
  hlg.white_point = jxl::WhitePoint::kD65;
  hlg.tf.SetTransferFunction(jxl::TransferFunction::kHLG);
  JXL_CHECK(hlg.CreateICC());
  JXL_CHECK(jpegxl::tools::TransformCodecInOutTo(image, hlg, &pool));
  image.metadata.m.color_encoding = hlg;
  JXL_CHECK(jxl::Encode(image, output_filename, &encoded, &pool));
  JXL_CHECK(jpegxl::tools::WriteFile(output_filename, encoded));
}
