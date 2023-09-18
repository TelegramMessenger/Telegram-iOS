// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef PLUGINS_GIMP_FILE_JXL_LOAD_H_
#define PLUGINS_GIMP_FILE_JXL_LOAD_H_

#include "plugins/gimp/common.h"

namespace jxl {

bool LoadJpegXlImage(const gchar* filename, gint32* image_id);

}  // namespace jxl

#endif  // PLUGINS_GIMP_FILE_JXL_LOAD_H_
