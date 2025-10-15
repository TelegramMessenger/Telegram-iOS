// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include <string>

#include "lib/extras/dec/color_description.h"

namespace jpegxl {
namespace tools {

int TestOneInput(const uint8_t* data, size_t size) {
  std::string description(reinterpret_cast<const char*>(data), size);
  JxlColorEncoding c;
  (void)jxl::ParseDescription(description, &c);

  return 0;
}

}  // namespace tools
}  // namespace jpegxl

extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size) {
  return jpegxl::tools::TestOneInput(data, size);
}
