// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include <stdio.h>
#include <stdlib.h>

#include "lib/extras/codec.h"
#include "lib/extras/dec/decode.h"
#include "lib/extras/packed_image_convert.h"
#include "lib/jxl/enc_color_management.h"
#include "lib/jxl/image_bundle.h"
#include "tools/cmdline.h"
#include "tools/file_io.h"
#include "tools/hdr/image_utils.h"
#include "tools/thread_pool_internal.h"

namespace {

struct LuminanceInfo {
  enum class Kind { kWhite, kMaximum };
  Kind kind = Kind::kWhite;
  float luminance = 100.f;
};

bool ParseLuminanceInfo(const char* argument, LuminanceInfo* luminance_info) {
  if (strncmp(argument, "white=", 6) == 0) {
    luminance_info->kind = LuminanceInfo::Kind::kWhite;
    argument += 6;
  } else if (strncmp(argument, "max=", 4) == 0) {
    luminance_info->kind = LuminanceInfo::Kind::kMaximum;
    argument += 4;
  } else {
    fprintf(stderr,
            "Invalid prefix for luminance info, expected white= or max=\n");
    return false;
  }
  return jpegxl::tools::ParseFloat(argument, &luminance_info->luminance);
}

}  // namespace

int main(int argc, const char** argv) {
  jpegxl::tools::ThreadPoolInternal pool;

  jpegxl::tools::CommandLineParser parser;
  LuminanceInfo luminance_info;
  auto luminance_option =
      parser.AddOptionValue('l', "luminance", "<max|white=N>",
                            "luminance information (defaults to whiteLuminance "
                            "header if present, otherwise to white=100)",
                            &luminance_info, &ParseLuminanceInfo, 0);
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

  jxl::extras::PackedPixelFile ppf;
  std::vector<uint8_t> input_bytes;
  JXL_CHECK(jpegxl::tools::ReadFile(input_filename, &input_bytes));
  JXL_CHECK(jxl::extras::DecodeBytes(jxl::Span<const uint8_t>(input_bytes),
                                     jxl::extras::ColorHints(), &ppf));

  jxl::CodecInOut image;
  JXL_CHECK(
      jxl::extras::ConvertPackedPixelFileToCodecInOut(ppf, &pool, &image));
  image.metadata.m.bit_depth.exponent_bits_per_sample = 0;
  jxl::ColorEncoding linear_rec_2020 = image.Main().c_current();
  linear_rec_2020.primaries = jxl::Primaries::k2100;
  linear_rec_2020.tf.SetTransferFunction(jxl::TransferFunction::kLinear);
  JXL_CHECK(linear_rec_2020.CreateICC());
  JXL_CHECK(
      jpegxl::tools::TransformCodecInOutTo(image, linear_rec_2020, &pool));

  float primaries_xyz[9];
  const jxl::PrimariesCIExy primaries = image.Main().c_current().GetPrimaries();
  const jxl::CIExy white_point = image.Main().c_current().GetWhitePoint();
  JXL_CHECK(jxl::PrimariesToXYZ(primaries.r.x, primaries.r.y, primaries.g.x,
                                primaries.g.y, primaries.b.x, primaries.b.y,
                                white_point.x, white_point.y, primaries_xyz));

  float max_value = 0.f;
  float max_relative_luminance = 0.f;
  float white_luminance = ppf.info.intensity_target != 0 &&
                                  !parser.GetOption(luminance_option)->matched()
                              ? ppf.info.intensity_target
                          : luminance_info.kind == LuminanceInfo::Kind::kWhite
                              ? luminance_info.luminance
                              : 0.f;
  bool out_of_gamut = false;
  for (size_t y = 0; y < image.ysize(); ++y) {
    const float* const rows[3] = {image.Main().color()->ConstPlaneRow(0, y),
                                  image.Main().color()->ConstPlaneRow(1, y),
                                  image.Main().color()->ConstPlaneRow(2, y)};
    for (size_t x = 0; x < image.xsize(); ++x) {
      if (!out_of_gamut &&
          (rows[0][x] < 0 || rows[1][x] < 0 || rows[2][x] < 0)) {
        out_of_gamut = true;
        fprintf(stderr,
                "WARNING: found colors outside of the Rec. 2020 gamut.\n");
      }
      max_value = std::max(
          max_value, std::max(rows[0][x], std::max(rows[1][x], rows[2][x])));
      const float luminance = primaries_xyz[1] * rows[0][x] +
                              primaries_xyz[4] * rows[1][x] +
                              primaries_xyz[7] * rows[2][x];
      if (luminance_info.kind == LuminanceInfo::Kind::kMaximum &&
          luminance > max_relative_luminance) {
        max_relative_luminance = luminance;
        white_luminance = luminance_info.luminance / luminance;
      }
    }
  }
  jxl::ScaleImage(1.f / max_value, image.Main().color());
  white_luminance *= max_value;
  image.metadata.m.SetIntensityTarget(white_luminance);
  if (white_luminance > 10000) {
    fprintf(stderr,
            "WARNING: the image is too bright for PQ (would need (1, 1, 1) to "
            "be %g cd/m^2).\n",
            white_luminance);
  } else {
    fprintf(stderr,
            "The resulting image should be compressed with "
            "--intensity_target=%g.\n",
            white_luminance);
  }

  jxl::ColorEncoding pq = image.Main().c_current();
  pq.tf.SetTransferFunction(jxl::TransferFunction::kPQ);
  JXL_CHECK(pq.CreateICC());
  JXL_CHECK(jpegxl::tools::TransformCodecInOutTo(image, pq, &pool));
  image.metadata.m.color_encoding = pq;
  std::vector<uint8_t> encoded;
  JXL_CHECK(jxl::Encode(image, output_filename, &encoded, &pool));
  JXL_CHECK(jpegxl::tools::WriteFile(output_filename, encoded));
}
