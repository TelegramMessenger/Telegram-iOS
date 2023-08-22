// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include <stdlib.h>

#include <QApplication>
#include <QCommandLineOption>
#include <QCommandLineParser>
#include <QFlags>
#include <QImage>
#include <QMessageBox>
#include <QStringList>

#include "tools/comparison_viewer/image_loading.h"
#include "tools/comparison_viewer/split_image_view.h"
#include "tools/icc_detect/icc_detect.h"

namespace {

void displayLoadingError(const QString& path) {
  QMessageBox message;
  message.setIcon(QMessageBox::Critical);
  message.setWindowTitle(
      QCoreApplication::translate("SplitImageView", "Error"));
  message.setText(QCoreApplication::translate("SplitImageView",
                                              "Could not load image \"%1\".")
                      .arg(path));
  message.exec();
}

}  // namespace

int main(int argc, char** argv) {
  QApplication application(argc, argv);

  QCommandLineParser parser;
  parser.setApplicationDescription(
      QCoreApplication::translate("compare_images", "Image comparison tool"));
  parser.addHelpOption();
  parser.addPositionalArgument(
      "left-image",
      QCoreApplication::translate("compare_images",
                                  "The image to display on the left."),
      "<left-image>");
  parser.addPositionalArgument(
      "right-image",
      QCoreApplication::translate("compare_images",
                                  "The image to display on the right."),
      "<right-image>");
  parser.addPositionalArgument(
      "middle-image",
      QCoreApplication::translate(
          "compare_images", "The image to display in the middle (optional)."),
      "[<middle-image>]");

  QCommandLineOption colorSpaceOption(
      {"color-space", "color_space", "c"},
      QCoreApplication::translate(
          "compare_images",
          "The color space to use for untagged images (typically PNM)."),
      QCoreApplication::translate("compare_images", "color-space"));
  parser.addOption(colorSpaceOption);

  QCommandLineOption intensityTargetOption(
      {"intensity-target", "intensity_target", "i"},
      QCoreApplication::translate("compare_images",
                                  "The peak luminance of the display."),
      QCoreApplication::translate("compare_images", "nits"),
      QString::number(jxl::kDefaultIntensityTarget));
  parser.addOption(intensityTargetOption);

  parser.process(application);

  const QString colorSpaceHint = parser.value(colorSpaceOption);

  QStringList arguments = parser.positionalArguments();
  if (arguments.size() < 2 || arguments.size() > 3) {
    parser.showHelp(EXIT_FAILURE);
  }

  bool ok;
  const float intensityTarget =
      parser.value(intensityTargetOption).toFloat(&ok);
  if (!ok) {
    parser.showHelp(EXIT_FAILURE);
  }

  jpegxl::tools::SplitImageView view;

  const QByteArray monitorIccProfile =
      jpegxl::tools::GetMonitorIccProfile(&view);

  const QString leftImagePath = arguments.takeFirst();
  QImage leftImage = jpegxl::tools::loadImage(leftImagePath, monitorIccProfile,
                                              intensityTarget, colorSpaceHint);
  if (leftImage.isNull()) {
    displayLoadingError(leftImagePath);
    return EXIT_FAILURE;
  }
  view.setLeftImage(std::move(leftImage));

  const QString rightImagePath = arguments.takeFirst();
  QImage rightImage = jpegxl::tools::loadImage(
      rightImagePath, monitorIccProfile, intensityTarget, colorSpaceHint);
  if (rightImage.isNull()) {
    displayLoadingError(rightImagePath);
    return EXIT_FAILURE;
  }
  view.setRightImage(std::move(rightImage));

  if (!arguments.empty()) {
    const QString middleImagePath = arguments.takeFirst();
    QImage middleImage = jpegxl::tools::loadImage(
        middleImagePath, monitorIccProfile, intensityTarget, colorSpaceHint);
    if (middleImage.isNull()) {
      displayLoadingError(middleImagePath);
      return EXIT_FAILURE;
    }
    view.setMiddleImage(std::move(middleImage));
  }

  view.setWindowFlags(view.windowFlags() | Qt::Window);
  view.setWindowState(Qt::WindowMaximized);
  view.show();

  return application.exec();
}
