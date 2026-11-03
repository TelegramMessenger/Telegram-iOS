// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include <stdio.h>

#include "lib/extras/codec.h"
#include "lib/jxl/color_management.h"
#include "lib/jxl/enc_color_management.h"
#include "lib/jxl/image_bundle.h"
#include "tools/file_io.h"
#include "tools/ssimulacra.h"

namespace ssimulacra {
namespace {

int PrintUsage(char** argv) {
  fprintf(stderr, "Usage: %s [-v] [-s] orig.png distorted.png\n", argv[0]);
  return 1;
}

int Run(int argc, char** argv) {
  if (argc < 2) return PrintUsage(argv);

  bool verbose = false, simple = false;
  int input_arg = 1;
  if (!strcmp(argv[input_arg], "-v")) {
    verbose = true;
    input_arg++;
  }
  if (!strcmp(argv[input_arg], "-s")) {
    simple = true;
    input_arg++;
  }
  if (argc < input_arg + 2) return PrintUsage(argv);

  jxl::CodecInOut io[2];
  for (size_t i = 0; i < 2; ++i) {
    std::vector<uint8_t> encoded;
    JXL_CHECK(jpegxl::tools::ReadFile(argv[input_arg + i], &encoded));
    JXL_CHECK(jxl::SetFromBytes(jxl::Span<const uint8_t>(encoded),
                                jxl::extras::ColorHints(), &io[i]));
  }
  jxl::ImageBundle& ib1 = io[0].Main();
  jxl::ImageBundle& ib2 = io[1].Main();
  JXL_CHECK(ib1.TransformTo(jxl::ColorEncoding::LinearSRGB(ib1.IsGray()),
                            jxl::GetJxlCms(), nullptr));
  JXL_CHECK(ib2.TransformTo(jxl::ColorEncoding::LinearSRGB(ib2.IsGray()),
                            jxl::GetJxlCms(), nullptr));
  jxl::Image3F& img1 = *ib1.color();
  jxl::Image3F& img2 = *ib2.color();
  if (img1.xsize() != img2.xsize() || img1.ysize() != img2.ysize()) {
    fprintf(stderr, "Image size mismatch\n");
    return 1;
  }
  if (img1.xsize() < 8 || img1.ysize() < 8) {
    fprintf(stderr, "Minimum image size is 8x8 pixels\n");
    return 1;
  }

  Ssimulacra ssimulacra = ComputeDiff(img1, img2, simple);

  if (verbose) {
    ssimulacra.PrintDetails();
  }
  printf("%.8f\n", ssimulacra.Score());
  return 0;
}

}  // namespace
}  // namespace ssimulacra

int main(int argc, char** argv) { return ssimulacra::Run(argc, argv); }
