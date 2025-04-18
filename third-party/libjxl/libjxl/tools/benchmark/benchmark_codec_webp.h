// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.
#ifndef TOOLS_BENCHMARK_BENCHMARK_CODEC_WEBP_H_
#define TOOLS_BENCHMARK_BENCHMARK_CODEC_WEBP_H_

// To support webp, install libwebp-dev and rerun cmake.

#include <string>

#include "lib/jxl/base/status.h"
#include "tools/benchmark/benchmark_args.h"
#include "tools/benchmark/benchmark_codec.h"

namespace jpegxl {
namespace tools {
ImageCodec* CreateNewWebPCodec(const BenchmarkArgs& args);

// Registers the webp-specific command line options.
Status AddCommandLineOptionsWebPCodec(BenchmarkArgs* args);
}  // namespace tools
}  // namespace jpegxl

#endif  // TOOLS_BENCHMARK_BENCHMARK_CODEC_WEBP_H_
