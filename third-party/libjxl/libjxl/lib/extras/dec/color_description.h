// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef LIB_EXTRAS_COLOR_DESCRIPTION_H_
#define LIB_EXTRAS_COLOR_DESCRIPTION_H_

#include <jxl/color_encoding.h>

#include <string>

#include "lib/jxl/base/status.h"

namespace jxl {

// Parse the color description into a JxlColorEncoding "RGB_D65_SRG_Rel_Lin".
Status ParseDescription(const std::string& description,
                        JxlColorEncoding* JXL_RESTRICT c);

}  // namespace jxl

#endif  // LIB_EXTRAS_COLOR_DESCRIPTION_H_
