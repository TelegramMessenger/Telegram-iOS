// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "tools/tool_version.h"

#ifdef JPEGXL_VERSION_FROM_GIT
#include "tool_version_git.h"
#endif

namespace jpegxl {
namespace tools {

const char* kJpegxlVersion = JPEGXL_VERSION;

}  // namespace tools
}  // namespace jpegxl
