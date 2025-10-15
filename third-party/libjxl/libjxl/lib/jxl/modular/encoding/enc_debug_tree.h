// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef LIB_JXL_MODULAR_ENCODING_ENC_DEBUG_TREE_H_
#define LIB_JXL_MODULAR_ENCODING_ENC_DEBUG_TREE_H_

#include <stddef.h>
#include <stdint.h>

#include <string>
#include <vector>

#include "lib/jxl/modular/encoding/dec_ma.h"
#include "lib/jxl/modular/options.h"

namespace jxl {

const char *PredictorName(Predictor p);
std::string PropertyName(size_t i);

void PrintTree(const Tree &tree, const std::string &path);

}  // namespace jxl

#endif  // LIB_JXL_MODULAR_ENCODING_ENC_DEBUG_TREE_H_
