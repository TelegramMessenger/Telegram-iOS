// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "tools/comparison_viewer/settings.h"

namespace jpegxl {
namespace tools {

SettingsDialog::SettingsDialog(QWidget* const parent)
    : QDialog(parent), settings_("JPEG XL project", "Comparison tool") {
  ui_.setupUi(this);

  settings_.beginGroup("rendering");
  renderingSettings_.fadingMSecs = settings_.value("fadingMSecs", 300).toInt();
  settings_.beginGroup("gray");
  renderingSettings_.gray = settings_.value("enabled", false).toBool();
  renderingSettings_.grayMSecs = settings_.value("delayMSecs", 300).toInt();
  settings_.endGroup();
  settings_.endGroup();

  settingsToUi();
}

SplitImageRenderingSettings SettingsDialog::renderingSettings() const {
  return renderingSettings_;
}

void SettingsDialog::on_SettingsDialog_accepted() {
  renderingSettings_.fadingMSecs = ui_.fadingTime->value();
  renderingSettings_.gray = ui_.grayGroup->isChecked();
  renderingSettings_.grayMSecs = ui_.grayTime->value();

  settings_.beginGroup("rendering");
  settings_.setValue("fadingMSecs", renderingSettings_.fadingMSecs);
  settings_.beginGroup("gray");
  settings_.setValue("enabled", renderingSettings_.gray);
  settings_.setValue("delayMSecs", renderingSettings_.grayMSecs);
  settings_.endGroup();
  settings_.endGroup();
}

void SettingsDialog::on_SettingsDialog_rejected() { settingsToUi(); }

void SettingsDialog::settingsToUi() {
  ui_.fadingTime->setValue(renderingSettings_.fadingMSecs);
  ui_.grayGroup->setChecked(renderingSettings_.gray);
  ui_.grayTime->setValue(renderingSettings_.grayMSecs);
}

}  // namespace tools
}  // namespace jpegxl
