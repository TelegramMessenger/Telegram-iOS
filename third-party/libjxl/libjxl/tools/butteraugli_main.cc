// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include <stdint.h>
#include <stdio.h>

#include <string>
#include <vector>

#include "lib/extras/codec.h"
#include "lib/extras/dec/color_hints.h"
#include "lib/extras/metrics.h"
#include "lib/jxl/base/data_parallel.h"
#include "lib/jxl/base/padded_bytes.h"
#include "lib/jxl/base/printf_macros.h"
#include "lib/jxl/base/span.h"
#include "lib/jxl/base/status.h"
#include "lib/jxl/butteraugli/butteraugli.h"
#include "lib/jxl/codec_in_out.h"
#include "lib/jxl/color_encoding_internal.h"
#include "lib/jxl/color_management.h"
#include "lib/jxl/enc_butteraugli_comparator.h"
#include "lib/jxl/enc_color_management.h"
#include "lib/jxl/image.h"
#include "lib/jxl/image_bundle.h"
#include "lib/jxl/image_ops.h"
#include "tools/file_io.h"
#include "tools/thread_pool_internal.h"

namespace {

using jpegxl::tools::ThreadPoolInternal;
using jxl::ButteraugliParams;
using jxl::CodecInOut;
using jxl::ColorEncoding;
using jxl::Image3F;
using jxl::ImageF;
using jxl::Status;

Status WriteImage(Image3F&& image, const std::string& filename) {
  ThreadPoolInternal pool(4);
  CodecInOut io;
  io.metadata.m.SetUintSamples(8);
  io.metadata.m.color_encoding = ColorEncoding::SRGB();
  io.SetFromImage(std::move(image), io.metadata.m.color_encoding);

  std::vector<uint8_t> encoded;
  return jxl::Encode(io, filename, &encoded, &pool) &&
         jpegxl::tools::WriteFile(filename, encoded);
}

Status RunButteraugli(const char* pathname1, const char* pathname2,
                      const std::string& distmap_filename,
                      const std::string& raw_distmap_filename,
                      const std::string& colorspace_hint, double p,
                      float intensity_target) {
  jxl::extras::ColorHints color_hints;
  if (!colorspace_hint.empty()) {
    color_hints.Add("color_space", colorspace_hint);
  }

  const char* pathname[2] = {pathname1, pathname2};
  CodecInOut io[2];
  ThreadPoolInternal pool(4);
  for (size_t i = 0; i < 2; ++i) {
    std::vector<uint8_t> encoded;
    if (!jpegxl::tools::ReadFile(pathname[i], &encoded)) {
      fprintf(stderr, "Failed to read image from %s\n", pathname[i]);
      return false;
    }
    if (!jxl::SetFromBytes(jxl::Span<const uint8_t>(encoded), color_hints,
                           &io[i], &pool)) {
      fprintf(stderr, "Failed to decode image from %s\n", pathname[i]);
      return false;
    }
  }

  CodecInOut& io1 = io[0];
  CodecInOut& io2 = io[1];
  if (io1.xsize() != io2.xsize()) {
    fprintf(stderr, "Width mismatch: %" PRIuS " %" PRIuS "\n", io1.xsize(),
            io2.xsize());
    return false;
  }
  if (io1.ysize() != io2.ysize()) {
    fprintf(stderr, "Height mismatch: %" PRIuS " %" PRIuS "\n", io1.ysize(),
            io2.ysize());
    return false;
  }

  ImageF distmap;
  ButteraugliParams ba_params;
  ba_params.hf_asymmetry = 1.0f;
  ba_params.xmul = 1.0f;
  ba_params.intensity_target = intensity_target;
  const float distance = jxl::ButteraugliDistance(
      io1.Main(), io2.Main(), ba_params, jxl::GetJxlCms(), &distmap, &pool);
  printf("%.10f\n", distance);

  double pnorm = jxl::ComputeDistanceP(distmap, ba_params, p);
  printf("%g-norm: %f\n", p, pnorm);

  if (!distmap_filename.empty()) {
    float good = jxl::ButteraugliFuzzyInverse(1.5);
    float bad = jxl::ButteraugliFuzzyInverse(0.5);
    JXL_CHECK(WriteImage(jxl::CreateHeatMapImage(distmap, good, bad),
                         distmap_filename));
  }
  if (!raw_distmap_filename.empty()) {
    FILE* out = fopen(raw_distmap_filename.c_str(), "w");
    JXL_CHECK(out != nullptr);
    fprintf(out, "Pf\n%" PRIuS " %" PRIuS "\n-1.0\n", distmap.xsize(),
            distmap.ysize());
    for (size_t y = distmap.ysize(); y-- > 0;) {
      fwrite(distmap.Row(y), 4, distmap.xsize(), out);
    }
    fclose(out);
  }
  return true;
}

}  // namespace

int main(int argc, char** argv) {
  if (argc < 3) {
    fprintf(stderr,
            "Usage: %s <reference> <distorted>\n"
            "  [--distmap <distmap>]\n"
            "  [--rawdistmap <distmap.pfm>]\n"
            "  [--intensity_target <intensity_target>]\n"
            "  [--colorspace <colorspace_hint>]\n"
            "  [--pnorm <pth norm>]\n"
            "NOTE: images get converted to linear sRGB for butteraugli. Images"
            " without attached profiles (such as ppm or pfm) are interpreted"
            " as nonlinear sRGB. The hint format is RGB_D65_SRG_Rel_Lin for"
            " linear sRGB. Intensity target is viewing conditions screen nits"
            ", defaults to 80.\n",
            argv[0]);
    return 1;
  }
  std::string distmap;
  std::string raw_distmap;
  std::string colorspace;
  double p = 3;
  float intensity_target = 80.0;  // sRGB intensity target.
  for (int i = 3; i < argc; i++) {
    if (std::string(argv[i]) == "--distmap" && i + 1 < argc) {
      distmap = argv[++i];
    } else if (std::string(argv[i]) == "--rawdistmap" && i + 1 < argc) {
      raw_distmap = argv[++i];
    } else if (std::string(argv[i]) == "--colorspace" && i + 1 < argc) {
      colorspace = argv[++i];
    } else if (std::string(argv[i]) == "--intensity_target" && i + 1 < argc) {
      intensity_target = std::stof(std::string(argv[++i]));
    } else if (std::string(argv[i]) == "--pnorm" && i + 1 < argc) {
      char* end;
      p = strtod(argv[++i], &end);
      if (end == argv[i]) {
        fprintf(stderr, "Failed to parse pnorm \"%s\".\n", argv[i]);
        return 1;
      }
    } else {
      fprintf(stderr, "Unrecognized flag \"%s\".\n", argv[i]);
      return 1;
    }
  }

  return !RunButteraugli(argv[1], argv[2], distmap, raw_distmap, colorspace, p,
                         intensity_target);
}
