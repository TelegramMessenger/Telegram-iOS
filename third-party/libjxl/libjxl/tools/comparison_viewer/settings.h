// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef TOOLS_COMPARISON_VIEWER_SETTINGS_H_
#define TOOLS_COMPARISON_VIEWER_SETTINGS_H_

#include <QDialog>
#include <QSettings>

#include "tools/comparison_viewer/split_image_renderer.h"
#include "tools/comparison_viewer/ui_settings.h"

namespace jpegxl {
namespace tools {

class SettingsDialog : public QDialog {
  Q_OBJECT

 public:
  explicit SettingsDialog(QWidget* parent = nullptr);
  ~SettingsDialog() override = default;

  SplitImageRenderingSettings renderingSettings() const;

 private slots:
  void on_SettingsDialog_accepted();
  void on_SettingsDialog_rejected();

 private:
  void settingsToUi();

  Ui::SettingsDialog ui_;
  QSettings settings_;
  SplitImageRenderingSettings renderingSettings_;
};

}  // namespace tools
}  // namespace jpegxl

#endif  // TOOLS_COMPARISON_VIEWER_SETTINGS_H_
