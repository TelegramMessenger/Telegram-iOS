// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "tools/flicker_test/parameters.h"

namespace jpegxl {
namespace tools {

namespace {

constexpr char kPathsGroup[] = "paths";
constexpr char kOriginalFolderKey[] = "originalFolder";
constexpr char kAlteredFolderKey[] = "alteredFolder";
constexpr char kOutputFileKey[] = "outputFile";

constexpr char kTimingGroup[] = "timing";
constexpr char kAdvanceTimeKey[] = "advanceTimeMSecs";
constexpr char kViewingTimeKey[] = "viewingTimeSecs";
constexpr char kBlankingTimeKey[] = "blankingTimeMSecs";
constexpr char kGrayGroup[] = "gray";
constexpr char kGrayKey[] = "enabled";
constexpr char kGrayFadingTimeKey[] = "fadingTimeMSecs";
constexpr char kGrayTimeKey[] = "timeMSecs";

constexpr char kDisplayGroup[] = "display";
constexpr char kIntensityTargetKey[] = "intensityTarget";
constexpr char kSpacingKey[] = "spacing";

}  // namespace

FlickerTestParameters FlickerTestParameters::loadFrom(
    QSettings* const settings) {
  FlickerTestParameters parameters;

  settings->beginGroup(kPathsGroup);
  parameters.originalFolder = settings->value(kOriginalFolderKey).toString();
  parameters.alteredFolder = settings->value(kAlteredFolderKey).toString();
  parameters.outputFile = settings->value(kOutputFileKey).toString();
  settings->endGroup();

  settings->beginGroup(kTimingGroup);
  parameters.advanceTimeMSecs = settings->value(kAdvanceTimeKey, 100).toInt();
  parameters.viewingTimeSecs = settings->value(kViewingTimeKey, 4).toInt();
  parameters.blankingTimeMSecs = settings->value(kBlankingTimeKey, 250).toInt();
  settings->beginGroup(kGrayGroup);
  parameters.gray = settings->value(kGrayKey, false).toBool();
  parameters.grayFadingTimeMSecs =
      settings->value(kGrayFadingTimeKey, 100).toInt();
  parameters.grayTimeMSecs = settings->value(kGrayTimeKey, 300).toInt();
  settings->endGroup();
  settings->endGroup();

  settings->beginGroup(kDisplayGroup);
  parameters.intensityTarget =
      settings->value(kIntensityTargetKey, 250).toInt();
  parameters.spacing = settings->value(kSpacingKey, 50).toInt();
  settings->endGroup();

  return parameters;
}

void FlickerTestParameters::saveTo(QSettings* const settings) const {
  settings->beginGroup(kPathsGroup);
  settings->setValue(kOriginalFolderKey, originalFolder);
  settings->setValue(kAlteredFolderKey, alteredFolder);
  settings->setValue(kOutputFileKey, outputFile);
  settings->endGroup();

  settings->beginGroup(kTimingGroup);
  settings->setValue(kAdvanceTimeKey, advanceTimeMSecs);
  settings->setValue(kViewingTimeKey, viewingTimeSecs);
  settings->setValue(kBlankingTimeKey, blankingTimeMSecs);
  settings->beginGroup(kGrayGroup);
  settings->setValue(kGrayKey, gray);
  settings->setValue(kGrayFadingTimeKey, grayFadingTimeMSecs);
  settings->setValue(kGrayTimeKey, grayTimeMSecs);
  settings->endGroup();
  settings->endGroup();

  settings->beginGroup(kDisplayGroup);
  settings->setValue(kIntensityTargetKey, intensityTarget);
  settings->setValue(kSpacingKey, spacing);
  settings->endGroup();
}

}  // namespace tools
}  // namespace jpegxl
