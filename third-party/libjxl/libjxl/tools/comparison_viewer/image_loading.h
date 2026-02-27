// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef TOOLS_COMPARISON_VIEWER_IMAGE_LOADING_H_
#define TOOLS_COMPARISON_VIEWER_IMAGE_LOADING_H_

#include <QByteArray>
#include <QImage>
#include <QString>

#include "lib/jxl/common.h"

namespace jpegxl {
namespace tools {

// `extension` should not include the dot.
bool canLoadImageWithExtension(QString extension);

// Converts the loaded image to the given display profile, or sRGB if not
// specified. Thread-hostile.
QImage loadImage(const QString& filename,
                 const QByteArray& targetIccProfile = QByteArray(),
                 float intensityTarget = jxl::kDefaultIntensityTarget,
                 const QString& sourceColorSpaceHint = QString());

}  // namespace tools
}  // namespace jpegxl

#endif  // TOOLS_COMPARISON_VIEWER_IMAGE_LOADING_H_
