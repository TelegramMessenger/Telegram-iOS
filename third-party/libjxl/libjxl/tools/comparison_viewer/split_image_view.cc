// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "tools/comparison_viewer/split_image_view.h"

#include <utility>

#include <QLabel>

#include "tools/comparison_viewer/split_image_renderer.h"

namespace jpegxl {
namespace tools {

SplitImageView::SplitImageView(QWidget* const parent) : QWidget(parent) {
  ui_.setupUi(this);

  ui_.splitImageRenderer->setRenderingSettings(settings_.renderingSettings());

  connect(ui_.middleWidthSlider, &QSlider::valueChanged,
          [this](const int value) {
            ui_.middleWidthDisplayLabel->setText(tr("%L1%").arg(value));
          });
  connect(ui_.middleWidthSlider, &QSlider::valueChanged, ui_.splitImageRenderer,
          &SplitImageRenderer::setMiddleWidthPercent);

  connect(ui_.zoomLevelSlider, &QSlider::valueChanged, [this](const int value) {
    if (value >= 0) {
      ui_.zoomLevelDisplayLabel->setText(tr("&times;%L1").arg(1 << value));
      ui_.splitImageRenderer->setZoomLevel(1 << value);
    } else {
      ui_.zoomLevelDisplayLabel->setText(tr("&times;1/%L1").arg(1 << -value));
      ui_.splitImageRenderer->setZoomLevel(1. / (1 << -value));
    }
  });

  connect(ui_.splitImageRenderer,
          &SplitImageRenderer::zoomLevelIncreaseRequested, [this]() {
            ui_.zoomLevelSlider->triggerAction(
                QAbstractSlider::SliderSingleStepAdd);
          });
  connect(ui_.splitImageRenderer,
          &SplitImageRenderer::zoomLevelDecreaseRequested, [this]() {
            ui_.zoomLevelSlider->triggerAction(
                QAbstractSlider::SliderSingleStepSub);
          });

  connect(ui_.splitImageRenderer, &SplitImageRenderer::renderingModeChanged,
          this, &SplitImageView::renderingModeChanged);
}

void SplitImageView::setLeftImage(QImage image) {
  ui_.splitImageRenderer->setLeftImage(std::move(image));
}

void SplitImageView::setRightImage(QImage image) {
  ui_.splitImageRenderer->setRightImage(std::move(image));
}

void SplitImageView::setMiddleImage(QImage image) {
  ui_.splitImageRenderer->setMiddleImage(std::move(image));
}

void SplitImageView::on_settingsButton_clicked() {
  if (settings_.exec()) {
    ui_.splitImageRenderer->setRenderingSettings(settings_.renderingSettings());
  }
}

}  // namespace tools
}  // namespace jpegxl
