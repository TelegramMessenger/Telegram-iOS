// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef TOOLS_BENCHMARK_BENCHMARK_CODEC_CUSTOM_H_
#define TOOLS_BENCHMARK_BENCHMARK_CODEC_CUSTOM_H_

// This is a benchmark codec that can be used with any command-line
// encoder/decoder that satisfies the following conditions:
//
// - the encoder can read from a PNG file `$input.png` and write the encoded
//   image to `$encoded.$ext` if it is called as:
//
//       $encoder [OPTIONS] $input.png $encoded.$ext
//
// - the decoder can read from an encoded file `$encoded.$ext` and write to a
//   PNG file `$decoded.png` if it is called as:
//
//       $decoder $encoded.$ext $decoded.png
//
// On the benchmark command line, the codec must be specified as:
//
//     custom:$ext:$encoder:$decoder:$options
//
// Where the options are also separated by colons.
//
// An example with JPEG XL itself would be:
//
//     custom:jxl:cjxl:djxl:--distance:3
//
// Optionally, to have encoding and decoding speed reported, the codec may write
// the number of seconds (as a floating point number) elapsed during actual
// encoding/decoding to $encoded.time and $decoded.time, respectively (replacing
// the .$ext and .png extensions).

#include "tools/benchmark/benchmark_args.h"
#include "tools/benchmark/benchmark_codec.h"

namespace jpegxl {
namespace tools {

ImageCodec* CreateNewCustomCodec(const BenchmarkArgs& args);
Status AddCommandLineOptionsCustomCodec(BenchmarkArgs* args);

}  // namespace tools
}  // namespace jpegxl

#endif  // TOOLS_BENCHMARK_BENCHMARK_CODEC_CUSTOM_H_
