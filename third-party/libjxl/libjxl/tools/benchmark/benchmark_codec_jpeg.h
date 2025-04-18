// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef TOOLS_BENCHMARK_BENCHMARK_CODEC_JPEG_H_
#define TOOLS_BENCHMARK_BENCHMARK_CODEC_JPEG_H_

#include "lib/jxl/base/status.h"
#include "tools/benchmark/benchmark_args.h"
#include "tools/benchmark/benchmark_codec.h"

namespace jpegxl {
namespace tools {
ImageCodec* CreateNewJPEGCodec(const BenchmarkArgs& args);

// Registers the jpeg-specific command line options.
Status AddCommandLineOptionsJPEGCodec(BenchmarkArgs* args);
}  // namespace tools
}  // namespace jpegxl

#endif  // TOOLS_BENCHMARK_BENCHMARK_CODEC_JPEG_H_
