// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef TOOLS_FLICKER_TEST_PARAMETERS_H_
#define TOOLS_FLICKER_TEST_PARAMETERS_H_

#include <QSettings>

namespace jpegxl {
namespace tools {

struct FlickerTestParameters {
  QString originalFolder;
  QString alteredFolder;
  QString outputFile;
  int advanceTimeMSecs;
  int viewingTimeSecs;
  int blankingTimeMSecs;
  bool gray;
  int grayFadingTimeMSecs;
  int grayTimeMSecs;
  int intensityTarget;
  int spacing;

  static FlickerTestParameters loadFrom(QSettings* settings);
  void saveTo(QSettings* settings) const;
};

}  // namespace tools
}  // namespace jpegxl

#endif  // TOOLS_FLICKER_TEST_PARAMETERS_H_
