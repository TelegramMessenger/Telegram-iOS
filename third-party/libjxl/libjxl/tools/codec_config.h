// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef TOOLS_CODEC_CONFIG_H_
#define TOOLS_CODEC_CONFIG_H_

#include <stdint.h>

#include <string>

namespace jpegxl {
namespace tools {

// Returns a short string describing the codec version (if known) and build
// settings such as sanitizers and SIMD targets. Used in the benchmark and
// command-line tools.
std::string CodecConfigString(uint32_t lib_version);

}  // namespace tools
}  // namespace jpegxl

#endif  // TOOLS_CODEC_CONFIG_H_
