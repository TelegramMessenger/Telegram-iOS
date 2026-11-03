// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#ifndef TOOLS_FLICKER_TEST_SETUP_H_
#define TOOLS_FLICKER_TEST_SETUP_H_

#include <QWizard>

#include "tools/flicker_test/parameters.h"
#include "tools/flicker_test/ui_setup.h"

namespace jpegxl {
namespace tools {

class FlickerTestWizard : public QWizard {
  Q_OBJECT

 public:
  explicit FlickerTestWizard(QWidget* parent = nullptr);
  ~FlickerTestWizard() override = default;

  FlickerTestParameters parameters() const;

 protected:
  bool validateCurrentPage() override;

 private slots:
  void on_originalFolderBrowseButton_clicked();
  void on_alteredFolderBrowseButton_clicked();
  void on_outputFileBrowseButton_clicked();

  void on_timingButtonBox_clicked(QAbstractButton* button);

  void updateTotalGrayTime();

 private:
  Ui::FlickerTestWizard ui_;
  QSettings settings_;
};

}  // namespace tools
}  // namespace jpegxl

#endif  // TOOLS_FLICKER_TEST_SETUP_H_
