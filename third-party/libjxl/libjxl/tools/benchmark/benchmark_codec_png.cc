// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "tools/benchmark/benchmark_codec_png.h"

#include <stddef.h>
#include <stdint.h>

#include <string>

#include "lib/extras/codec.h"
#include "lib/extras/dec/apng.h"
#include "lib/extras/enc/apng.h"
#include "lib/extras/packed_image.h"
#include "lib/extras/packed_image_convert.h"
#include "lib/extras/time.h"
#include "lib/jxl/base/padded_bytes.h"
#include "lib/jxl/base/span.h"
#include "lib/jxl/codec_in_out.h"
#include "lib/jxl/image_bundle.h"
#include "lib/jxl/image_metadata.h"
#include "tools/thread_pool_internal.h"

namespace jpegxl {
namespace tools {

struct PNGArgs {
  // Empty, no PNG-specific args currently.
};

static PNGArgs* const pngargs = new PNGArgs;

Status AddCommandLineOptionsPNGCodec(BenchmarkArgs* args) { return true; }

// Lossless.
class PNGCodec : public ImageCodec {
 public:
  explicit PNGCodec(const BenchmarkArgs& args) : ImageCodec(args) {}

  Status ParseParam(const std::string& param) override { return true; }

  Status Compress(const std::string& filename, const CodecInOut* io,
                  ThreadPool* pool, std::vector<uint8_t>* compressed,
                  jpegxl::tools::SpeedStats* speed_stats) override {
    const size_t bits = io->metadata.m.bit_depth.bits_per_sample;
    const double start = jxl::Now();
    JXL_RETURN_IF_ERROR(jxl::Encode(*io, jxl::extras::Codec::kPNG,
                                    io->Main().c_current(), bits, compressed,
                                    pool));
    const double end = jxl::Now();
    speed_stats->NotifyElapsed(end - start);
    return true;
  }

  Status Decompress(const std::string& /*filename*/,
                    const Span<const uint8_t> compressed, ThreadPool* pool,
                    CodecInOut* io,
                    jpegxl::tools::SpeedStats* speed_stats) override {
    jxl::extras::PackedPixelFile ppf;
    const double start = jxl::Now();
    JXL_RETURN_IF_ERROR(jxl::extras::DecodeImageAPNG(
        compressed, jxl::extras::ColorHints(), &ppf));
    const double end = jxl::Now();
    speed_stats->NotifyElapsed(end - start);
    JXL_RETURN_IF_ERROR(
        jxl::extras::ConvertPackedPixelFileToCodecInOut(ppf, pool, io));
    return true;
  }
};

ImageCodec* CreateNewPNGCodec(const BenchmarkArgs& args) {
  if (jxl::extras::GetAPNGEncoder() &&
      jxl::extras::CanDecode(jxl::extras::Codec::kPNG)) {
    return new PNGCodec(args);
  } else {
    return nullptr;
  }
}

}  // namespace tools
}  // namespace jpegxl

