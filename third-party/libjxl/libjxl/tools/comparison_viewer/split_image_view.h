// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef TOOLS_COMPARISON_VIEWER_SPLIT_IMAGE_VIEW_H_
#define TOOLS_COMPARISON_VIEWER_SPLIT_IMAGE_VIEW_H_

#include <QWidget>

#include "tools/comparison_viewer/settings.h"
#include "tools/comparison_viewer/ui_split_image_view.h"

namespace jpegxl {
namespace tools {

class SplitImageView : public QWidget {
  Q_OBJECT

 public:
  explicit SplitImageView(QWidget* parent = nullptr);
  ~SplitImageView() override = default;

  void setLeftImage(QImage image);
  void setRightImage(QImage image);
  void setMiddleImage(QImage image);

 signals:
  void renderingModeChanged(SplitImageRenderer::RenderingMode newMode);

 private slots:
  void on_settingsButton_clicked();

 private:
  Ui::SplitImageView ui_;
  SettingsDialog settings_;
};

}  // namespace tools
}  // namespace jpegxl

#endif  // TOOLS_COMPARISON_VIEWER_SPLIT_IMAGE_VIEW_H_
