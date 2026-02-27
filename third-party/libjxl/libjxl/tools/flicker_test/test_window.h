// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef TOOLS_FLICKER_TEST_TEST_WINDOW_H_
#define TOOLS_FLICKER_TEST_TEST_WINDOW_H_

#include <QByteArray>
#include <QDir>
#include <QMainWindow>
#include <QStringList>
#include <QTextStream>

#include "tools/comparison_viewer/image_loading.h"
#include "tools/flicker_test/parameters.h"
#include "tools/flicker_test/ui_test_window.h"

namespace jpegxl {
namespace tools {

class FlickerTestWindow : public QMainWindow {
  Q_OBJECT

 public:
  explicit FlickerTestWindow(FlickerTestParameters parameters,
                             QWidget* parent = nullptr);
  ~FlickerTestWindow() override = default;

  bool proceedWithTest() const { return proceed_; }

 private slots:
  void processTestResult(const QString& imageName, SplitView::Side originalSide,
                         SplitView::Side clickedSide, int clickDelayMSecs);

 private:
  void nextImage();

  Ui::FlickerTestWindow ui_;
  bool proceed_ = true;
  const QByteArray monitorProfile_;
  FlickerTestParameters parameters_;
  QDir originalFolder_, alteredFolder_;
  QFile outputFile_;
  QTextStream outputStream_;
  QStringList remainingImages_;
};

}  // namespace tools
}  // namespace jpegxl

#endif  // TOOLS_FLICKER_TEST_TEST_WINDOW_H_
