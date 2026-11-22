// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "tools/flicker_test/test_window.h"

#include <QDir>
#include <QMessageBox>
#include <QSet>
#include <algorithm>
#include <random>

#include "tools/icc_detect/icc_detect.h"

namespace jpegxl {
namespace tools {

FlickerTestWindow::FlickerTestWindow(FlickerTestParameters parameters,
                                     QWidget* const parent)
    : QMainWindow(parent),
      monitorProfile_(GetMonitorIccProfile(this)),
      parameters_(std::move(parameters)),
      originalFolder_(parameters_.originalFolder, "*.png"),
      alteredFolder_(parameters_.alteredFolder, "*.png"),
      outputFile_(parameters_.outputFile) {
  ui_.setupUi(this);
  ui_.splitView->setSpacing(parameters_.spacing);
  ui_.endLabel->setText(
      tr("The test is complete and the results have been saved to \"%1\".")
          .arg(parameters_.outputFile));
  connect(ui_.startButton, &QAbstractButton::clicked, [&] {
    ui_.stackedView->setCurrentWidget(ui_.splitView);
    nextImage();
  });
  connect(ui_.splitView, &SplitView::testResult, this,
          &FlickerTestWindow::processTestResult);

  if (!outputFile_.open(QIODevice::WriteOnly)) {
    QMessageBox messageBox;
    messageBox.setIcon(QMessageBox::Critical);
    messageBox.setStandardButtons(QMessageBox::Close);
    messageBox.setWindowTitle(tr("Failed to open output file"));
    messageBox.setInformativeText(
        tr("Could not open \"%1\" for writing.").arg(outputFile_.fileName()));
    messageBox.exec();
    proceed_ = false;
    return;
  }
  outputStream_.setDevice(&outputFile_);
  outputStream_ << "image name,original side,clicked side,click delay (ms)\n";

  if (monitorProfile_.isEmpty()) {
    QMessageBox messageBox;
    messageBox.setIcon(QMessageBox::Warning);
    messageBox.setStandardButtons(QMessageBox::Ok);
    messageBox.setWindowTitle(tr("No monitor profile found"));
    messageBox.setText(
        tr("No ICC profile appears to be associated with the display. It will "
           "be assumed to match sRGB."));
    messageBox.exec();
  }

  originalFolder_.setFilter(QDir::Files);
  alteredFolder_.setFilter(QDir::Files);

#if QT_VERSION < QT_VERSION_CHECK(5, 14, 0)
  auto originalImages = QSet<QString>::fromList(originalFolder_.entryList());
  auto alteredImages = QSet<QString>::fromList(alteredFolder_.entryList());
#else
  const QStringList originalFolderEntries = originalFolder_.entryList();
  QSet<QString> originalImages(originalFolderEntries.begin(),
                               originalFolderEntries.end());
  const QStringList alteredFolderEntries = alteredFolder_.entryList();
  QSet<QString> alteredImages(alteredFolderEntries.begin(),
                              alteredFolderEntries.end());
#endif

  auto onlyOriginal = originalImages - alteredImages,
       onlyAltered = alteredImages - originalImages;
  if (!onlyOriginal.isEmpty() || !onlyAltered.isEmpty()) {
    QMessageBox messageBox;
    messageBox.setIcon(QMessageBox::Warning);
    messageBox.setStandardButtons(QMessageBox::Ok | QMessageBox::Cancel);
    messageBox.setWindowTitle(tr("Image set mismatch"));
    messageBox.setText(
        tr("A mismatch has been detected between the original and altered "
           "images."));
    messageBox.setInformativeText(tr("Proceed with the test?"));
    QStringList detailedTextParagraphs;
    const QString itemFormat = tr("— %1\n");
    if (!onlyOriginal.isEmpty()) {
      QString originalList;
      for (const QString& original : onlyOriginal) {
        originalList += itemFormat.arg(original);
      }
      detailedTextParagraphs << tr("The following images were only found in "
                                   "the originals folder:\n%1")
                                    .arg(originalList);
    }
    if (!onlyAltered.isEmpty()) {
      QString alteredList;
      for (const QString& altered : onlyAltered) {
        alteredList += itemFormat.arg(altered);
      }
      detailedTextParagraphs << tr("The following images were only found in "
                                   "the altered images folder:\n%1")
                                    .arg(alteredList);
    }
    messageBox.setDetailedText(detailedTextParagraphs.join("\n\n"));
    if (messageBox.exec() == QMessageBox::Cancel) {
      proceed_ = false;
      return;
    }
  }

  remainingImages_ = originalImages.intersect(alteredImages).values();
  std::random_device rd;
  std::mt19937 g(rd());
  std::shuffle(remainingImages_.begin(), remainingImages_.end(), g);
}

void FlickerTestWindow::processTestResult(const QString& imageName,
                                          const SplitView::Side originalSide,
                                          const SplitView::Side clickedSide,
                                          const int clickDelayMSecs) {
  const auto sideToString = [](const SplitView::Side side) {
    switch (side) {
      case SplitView::Side::kLeft:
        return "left";

      case SplitView::Side::kRight:
        return "right";
    }
    return "unknown";
  };
  outputStream_ << imageName << "," << sideToString(originalSide) << ","
                << sideToString(clickedSide) << "," << clickDelayMSecs << "\n";

  nextImage();
}

void FlickerTestWindow::nextImage() {
  if (remainingImages_.empty()) {
    outputStream_.flush();
    ui_.stackedView->setCurrentWidget(ui_.finalPage);
    return;
  }
  const QString image = remainingImages_.takeFirst();
retry:
  QImage originalImage =
      loadImage(originalFolder_.absoluteFilePath(image), monitorProfile_,
                parameters_.intensityTarget);
  QImage alteredImage = loadImage(alteredFolder_.absoluteFilePath(image),
                                  monitorProfile_, parameters_.intensityTarget);
  if (originalImage.isNull() || alteredImage.isNull()) {
    QMessageBox messageBox(this);
    messageBox.setIcon(QMessageBox::Warning);
    messageBox.setStandardButtons(QMessageBox::Retry | QMessageBox::Ignore |
                                  QMessageBox::Abort);
    messageBox.setWindowTitle(tr("Failed to load image"));
    messageBox.setText(tr("Could not load image \"%1\".").arg(image));
    switch (messageBox.exec()) {
      case QMessageBox::Retry:
        goto retry;

      case QMessageBox::Ignore:
        outputStream_ << image << ",,,\n";
        return nextImage();

      case QMessageBox::Abort:
        ui_.stackedView->setCurrentWidget(ui_.finalPage);
        return;
    }
  }

  ui_.splitView->setOriginalImage(std::move(originalImage));
  ui_.splitView->setAlteredImage(std::move(alteredImage));
  ui_.splitView->startTest(
      image, parameters_.blankingTimeMSecs, parameters_.viewingTimeSecs,
      parameters_.advanceTimeMSecs, parameters_.gray,
      parameters_.grayFadingTimeMSecs, parameters_.grayTimeMSecs);
}

}  // namespace tools
}  // namespace jpegxl
