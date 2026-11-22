// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef TOOLS_ICC_DETECT_ICC_DETECT_H_
#define TOOLS_ICC_DETECT_ICC_DETECT_H_

#include <QByteArray>
#include <QWidget>

namespace jpegxl {
namespace tools {

// Should be cached if possible.
QByteArray GetMonitorIccProfile(const QWidget* widget);

}  // namespace tools
}  // namespace jpegxl

#endif  // TOOLS_ICC_DETECT_ICC_DETECT_H_
