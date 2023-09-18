// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef TOOLS_TOOL_VERSION_H_
#define TOOLS_TOOL_VERSION_H_

#include <string>

namespace jpegxl {
namespace tools {

// Package version as defined by the JPEGXL_VERSION macro. This is not the
// library semantic versioning number, but instead additional information on the
// tool version.
extern const char* kJpegxlVersion;

}  // namespace tools
}  // namespace jpegxl

#endif  // TOOLS_TOOL_VERSION_H_
