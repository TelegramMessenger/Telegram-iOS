// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "tools/icc_detect/icc_detect.h"

namespace jpegxl {
namespace tools {

QByteArray GetMonitorIccProfile(const QWidget* const /*widget*/) {
  return QByteArray();
}

}  // namespace tools
}  // namespace jpegxl
