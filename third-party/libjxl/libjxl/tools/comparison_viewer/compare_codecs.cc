// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include <stdlib.h>

#include <QApplication>
#include <QCommandLineParser>
#include <QMessageBox>
#include <QString>
#include <QStringList>

#include "tools/comparison_viewer/codec_comparison_window.h"

int main(int argc, char** argv) {
  QApplication application(argc, argv);

  QCommandLineParser parser;
  parser.setApplicationDescription(
      QCoreApplication::translate("compare_codecs", "Codec comparison tool"));
  parser.addHelpOption();

  QCommandLineOption intensityTargetOption(
      {"intensity-target", "intensity_target", "i"},
      QCoreApplication::translate("compare_codecs",
                                  "The peak luminance of the display."),
      QCoreApplication::translate("compare_codecs", "nits"),
      QString::number(jxl::kDefaultIntensityTarget));
  parser.addOption(intensityTargetOption);

  parser.addPositionalArgument(
      "folders", QCoreApplication::translate("compare_codecs", "Image folders"),
      "<folders>...");

  parser.process(application);

  bool ok;
  const float intensityTarget =
      parser.value(intensityTargetOption).toFloat(&ok);
  if (!ok) {
    parser.showHelp(EXIT_FAILURE);
  }

  QStringList folders = parser.positionalArguments();

  if (folders.empty()) {
    QMessageBox message;
    message.setIcon(QMessageBox::Information);
    message.setWindowTitle(
        QCoreApplication::translate("CodecComparisonWindow", "Usage"));
    message.setText(QCoreApplication::translate(
        "CodecComparisonWindow", "Please specify a directory to use."));
    message.setDetailedText(QCoreApplication::translate(
        "CodecComparisonWindow",
        "That directory should contain images in the following layout:\n"
        "- .../<image name>/original.png (optional)\n"
        "- .../<image_name>/<codec_name>/<compression_level>.<ext>\n"
        "- .../<image_name>/<codec_name>/<compression_level>.png (optional for "
        "formats that Qt can load)\n"
        "With arbitrary nesting allowed before that. (The \"...\" part is "
        "referred to as an \"image set\" by the tool."));
    message.exec();
    return EXIT_FAILURE;
  }

  for (const QString& folder : folders) {
    auto* const window =
        new jpegxl::tools::CodecComparisonWindow(folder, intensityTarget);
    window->setAttribute(Qt::WA_DeleteOnClose);
    window->show();
  }

  return application.exec();
}
