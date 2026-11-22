// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef TOOLS_FLICKER_TEST_SPLIT_VIEW_H_
#define TOOLS_FLICKER_TEST_SPLIT_VIEW_H_

#include <QElapsedTimer>
#include <QImage>
#include <QPixmap>
#include <QTimer>
#include <QVariantAnimation>
#include <QWidget>
#include <random>

namespace jpegxl {
namespace tools {

class SplitView : public QWidget {
  Q_OBJECT

 public:
  enum class Side {
    kLeft,
    kRight,
  };
  Q_ENUM(Side)

  explicit SplitView(QWidget* parent = nullptr);
  ~SplitView() override = default;

  void setOriginalImage(QImage image);
  void setAlteredImage(QImage image);

 signals:
  void testResult(const QString& imageName, Side flickeringSide,
                  Side clickedSide, int clickDelayMSecs);

 public slots:
  void setSpacing(int spacing);
  void startTest(QString imageName, int blankingTimeMSecs, int viewingTimeSecs,
                 int advanceTimeMSecs, bool gray, int grayFadingTimeMSecs,
                 int grayTimeMSecs);

 protected:
  void mousePressEvent(QMouseEvent* event) override;
  void mouseReleaseEvent(QMouseEvent* event) override;
  void paintEvent(QPaintEvent* event) override;

 private slots:
  void startDisplaying();

 private:
  enum class State {
    kBlanking,
    kDisplaying,
  };

  void updateMinimumSize();

  int spacing_ = 50;

  std::mt19937 g_;

  QString imageName_;
  QPixmap original_, altered_;
  Side originalSide_;
  bool clicking_ = false;
  Side clickedSide_;
  QRectF leftRect_, rightRect_;
  State state_ = State::kDisplaying;
  bool gray_ = false;
  QTimer blankingTimer_;
  QTimer viewingTimer_;
  // Throughout each cycle, animates the opacity of the image being displayed
  // between 0 and 1 if fading to gray is enabled.
  QVariantAnimation flicker_;
  bool showingAltered_ = true;
  QElapsedTimer viewingStartTime_;
};

}  // namespace tools
}  // namespace jpegxl

#endif  // TOOLS_FLICKER_TEST_SPLIT_VIEW_H_
