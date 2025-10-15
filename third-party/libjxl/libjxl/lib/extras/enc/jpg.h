// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef LIB_EXTRAS_ENC_JPG_H_
#define LIB_EXTRAS_ENC_JPG_H_

// Encodes JPG pixels and metadata in memory.

#include <memory>

#include "lib/extras/enc/encode.h"

namespace jxl {
namespace extras {

std::unique_ptr<Encoder> GetJPEGEncoder();

}  // namespace extras
}  // namespace jxl

#endif  // LIB_EXTRAS_ENC_JPG_H_
