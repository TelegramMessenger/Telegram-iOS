// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "tools/flicker_test/split_view.h"

#include <QMouseEvent>
#include <QPainter>

namespace jpegxl {
namespace tools {

SplitView::SplitView(QWidget* const parent)
    : QWidget(parent), g_(std::random_device()()) {
  blankingTimer_.setSingleShot(true);
  blankingTimer_.setTimerType(Qt::PreciseTimer);
  viewingTimer_.setSingleShot(true);
  viewingTimer_.setTimerType(Qt::PreciseTimer);
  flicker_.setLoopCount(-1);
  connect(&blankingTimer_, &QTimer::timeout, this, &SplitView::startDisplaying);
  connect(&flicker_, &QVariantAnimation::valueChanged, this, [&] {
    if (gray_) {
      update();
    }
  });
  connect(&flicker_, &QAbstractAnimation::currentLoopChanged, [&] {
    showingAltered_ = !showingAltered_;
    update();
  });
  connect(&viewingTimer_, &QTimer::timeout, [&] {
    flicker_.stop();
    original_.fill(Qt::black);
    altered_.fill(Qt::black);
    update();
  });
}

void SplitView::setOriginalImage(QImage image) {
  original_ = QPixmap::fromImage(std::move(image));
  original_.setDevicePixelRatio(devicePixelRatio());
  updateMinimumSize();
  update();
}

void SplitView::setAlteredImage(QImage image) {
  altered_ = QPixmap::fromImage(std::move(image));
  altered_.setDevicePixelRatio(devicePixelRatio());
  updateMinimumSize();
  update();
}

void SplitView::setSpacing(int spacing) {
  spacing_ = spacing;
  updateMinimumSize();
  update();
}

void SplitView::startTest(QString imageName, const int blankingTimeMSecs,
                          const int viewingTimeSecs, const int advanceTimeMSecs,
                          const bool gray, const int grayFadingTimeMSecs,
                          const int grayTimeMSecs) {
  imageName_ = std::move(imageName);
  std::bernoulli_distribution bernoulli;
  originalSide_ = bernoulli(g_) ? Side::kLeft : Side::kRight;
  viewingTimer_.setInterval(1000 * viewingTimeSecs);

  flicker_.setDuration(advanceTimeMSecs);
  gray_ = gray;
  QVariantAnimation::KeyValues keyValues;
  if (gray_) {
    keyValues << QVariantAnimation::KeyValue(0., 0.f)
              << QVariantAnimation::KeyValue(
                     static_cast<float>(grayFadingTimeMSecs) / advanceTimeMSecs,
                     1.f)
              << QVariantAnimation::KeyValue(
                     static_cast<float>(advanceTimeMSecs - grayTimeMSecs -
                                        grayFadingTimeMSecs) /
                         advanceTimeMSecs,
                     1.f)
              << QVariantAnimation::KeyValue(
                     static_cast<float>(advanceTimeMSecs - grayTimeMSecs) /
                         advanceTimeMSecs,
                     0.f)
              << QVariantAnimation::KeyValue(1.f, 0.f);
  } else {
    keyValues << QVariantAnimation::KeyValue(0., 1.f)
              << QVariantAnimation::KeyValue(1., 1.f);
  }
  flicker_.setKeyValues(keyValues);

  state_ = State::kBlanking;
  blankingTimer_.start(blankingTimeMSecs);
}

void SplitView::mousePressEvent(QMouseEvent* const event) {
  if (state_ != State::kDisplaying) return;

  if (leftRect_.contains(event->pos())) {
    clicking_ = true;
    clickedSide_ = Side::kLeft;
  } else if (rightRect_.contains(event->pos())) {
    clicking_ = true;
    clickedSide_ = Side::kRight;
  }
}

void SplitView::mouseReleaseEvent(QMouseEvent* const event) {
  if (!clicking_) return;
  clicking_ = false;

  const int clickDelayMSecs = viewingStartTime_.elapsed();

  if ((clickedSide_ == Side::kLeft && !leftRect_.contains(event->pos())) ||
      (clickedSide_ == Side::kRight && !rightRect_.contains(event->pos()))) {
    return;
  }

  flicker_.stop();
  viewingTimer_.stop();
  state_ = State::kBlanking;
  update();

  emit testResult(imageName_, originalSide_, clickedSide_, clickDelayMSecs);
}

void SplitView::paintEvent(QPaintEvent* const event) {
  QPainter painter(this);
  painter.fillRect(rect(), QColor(119, 119, 119));

  if (state_ == State::kBlanking) return;

  if (gray_ && flicker_.state() == QAbstractAnimation::Running) {
    painter.setOpacity(flicker_.currentValue().toFloat());
  }

  const auto imageForSide = [&](const Side side) {
    if (side == originalSide_) return &original_;
    return showingAltered_ ? &altered_ : &original_;
  };

  QPixmap* const leftImage = imageForSide(Side::kLeft);
  QPixmap* const rightImage = imageForSide(Side::kRight);

  leftRect_ = QRectF(QPoint(), leftImage->deviceIndependentSize());
  leftRect_.moveCenter(rect().center());
  leftRect_.moveRight(rect().center().x() -
                      (spacing_ / 2 + spacing_ % 2) / devicePixelRatio());
  painter.drawPixmap(leftRect_.topLeft(), *leftImage);

  rightRect_ = QRectF(QPoint(), rightImage->deviceIndependentSize());
  rightRect_.moveCenter(rect().center());
  rightRect_.moveLeft(rect().center().x() +
                      (spacing_ / 2) / devicePixelRatio());
  painter.drawPixmap(rightRect_.topLeft(), *rightImage);
}

void SplitView::startDisplaying() {
  state_ = State::kDisplaying;
  flicker_.start();
  viewingStartTime_.start();
  if (viewingTimer_.interval() > 0) {
    viewingTimer_.start();
  }
}

void SplitView::updateMinimumSize() {
  setMinimumWidth(2 * std::max(original_.deviceIndependentSize().width(),
                               altered_.deviceIndependentSize().width()) +
                  spacing_ / devicePixelRatio());
  setMinimumHeight(std::max(original_.deviceIndependentSize().height(),
                            altered_.deviceIndependentSize().height()));
}

}  // namespace tools
}  // namespace jpegxl
