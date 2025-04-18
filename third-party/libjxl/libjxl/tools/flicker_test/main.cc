// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include <QApplication>

#include "tools/flicker_test/setup.h"
#include "tools/flicker_test/test_window.h"

int main(int argc, char** argv) {
  QApplication application(argc, argv);

  jpegxl::tools::FlickerTestWizard wizard;
  if (wizard.exec()) {
    jpegxl::tools::FlickerTestWindow test_window(wizard.parameters());
    if (test_window.proceedWithTest()) {
      test_window.showMaximized();
      return application.exec();
    }
  }
  return 0;
}
