// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "tools/wasm_demo/jxl_decompressor.h"

#include <jxl/thread_parallel_runner_cxx.h>

#include <cstring>
#include <memory>

#include "lib/extras/dec/jxl.h"
#include "tools/wasm_demo/no_png.h"

extern "C" {

namespace {

struct DecompressorOutputPrivate {
  // Due to "Standard Layout" rules it is guaranteed that address of the entity
  // and its first non-static member are the same.
  DecompressorOutput output;
};

void MaybeMakeCicp(const jxl::extras::PackedPixelFile& ppf,
                   std::vector<uint8_t>* cicp) {
  cicp->clear();
  const JxlColorEncoding& clr = ppf.color_encoding;
  uint8_t color_primaries = 0;
  uint8_t transfer_function = static_cast<uint8_t>(clr.transfer_function);

  if (clr.color_space != JXL_COLOR_SPACE_RGB) {
    return;
  }
  if (clr.primaries == JXL_PRIMARIES_P3) {
    if (clr.white_point == JXL_WHITE_POINT_D65) {
      color_primaries = 12;
    } else if (clr.white_point == JXL_WHITE_POINT_DCI) {
      color_primaries = 11;
    } else {
      return;
    }
  } else if (clr.primaries != JXL_PRIMARIES_CUSTOM &&
             clr.white_point == JXL_WHITE_POINT_D65) {
    color_primaries = static_cast<uint8_t>(clr.primaries);
  } else {
    return;
  }
  if (clr.transfer_function == JXL_TRANSFER_FUNCTION_UNKNOWN ||
      clr.transfer_function == JXL_TRANSFER_FUNCTION_GAMMA) {
    return;
  }

  cicp->resize(4);
  cicp->at(0) = color_primaries;    // Colour Primaries
  cicp->at(1) = transfer_function;  // Transfer Function
  cicp->at(2) = 0;                  // Matrix Coefficients
  cicp->at(3) = 1;                  // Video Full Range Flag
}

}  // namespace

DecompressorOutput* jxlDecompress(const uint8_t* input, size_t input_size) {
  DecompressorOutputPrivate* self = new DecompressorOutputPrivate();

  if (!self) {
    return nullptr;
  }

  auto report_error = [&](uint32_t code, const char* text) {
    fprintf(stderr, "%s\n", text);
    delete self;
    return reinterpret_cast<DecompressorOutput*>(code);
  };

  auto thread_pool = JxlThreadParallelRunnerMake(nullptr, 4);
  void* runner = thread_pool.get();

  jxl::extras::JXLDecompressParams dparams;
  JxlPixelFormat format = {/* num_channels */ 3, JXL_TYPE_UINT16,
                           JXL_BIG_ENDIAN, /* align */ 0};
  dparams.accepted_formats.push_back(format);
  dparams.runner = JxlThreadParallelRunner;
  dparams.runner_opaque = runner;
  jxl::extras::PackedPixelFile ppf;

  if (!jxl::extras::DecodeImageJXL(input, input_size, dparams, nullptr, &ppf)) {
    return report_error(1, "failed to decode jxl");
  }

  // Just 1-st frame.
  const auto& image = ppf.frames[0].color;
  std::vector<uint8_t> cicp;
  MaybeMakeCicp(ppf, &cicp);
  self->output.data = WrapPixelsToPng(
      image.xsize, image.ysize, (format.data_type == JXL_TYPE_UINT16) ? 16 : 8,
      /* has_alpha */ false, reinterpret_cast<const uint8_t*>(image.pixels()),
      ppf.icc, cicp, &self->output.size);
  if (!self->output.data) {
    return report_error(2, "failed to encode png");
  }

  return &self->output;
}

void jxlCleanup(DecompressorOutput* output) {
  if (output == nullptr) return;
  DecompressorOutputPrivate* self =
      reinterpret_cast<DecompressorOutputPrivate*>(output);
  if (self->output.data) {
    free(self->output.data);
  }
  delete self;
}

}  // extern "C"
