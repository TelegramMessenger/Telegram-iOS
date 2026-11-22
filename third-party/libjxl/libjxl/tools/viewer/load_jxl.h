// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef TOOLS_VIEWER_LOAD_JXL_H_
#define TOOLS_VIEWER_LOAD_JXL_H_

#include <QByteArray>
#include <QImage>
#include <QString>

namespace jpegxl {
namespace tools {

QImage loadJxlImage(const QString& filename, const QByteArray& targetIccProfile,
                    qint64* elapsed, bool* usedRequestedProfile = nullptr);

}  // namespace tools
}  // namespace jpegxl

#endif  // TOOLS_VIEWER_LOAD_JXL_H_
