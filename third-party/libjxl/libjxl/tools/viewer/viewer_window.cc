// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "tools/viewer/viewer_window.h"

#include <QElapsedTimer>
#include <QFileDialog>
#include <QFileInfo>
#include <QKeyEvent>
#include <QMessageBox>
#include <QSet>

#include "tools/icc_detect/icc_detect.h"
#include "tools/viewer/load_jxl.h"

namespace jpegxl {
namespace tools {

namespace {

template <typename Output>
void recursivelyAddSubEntries(const QFileInfo& info,
                              QSet<QString>* const visited,
                              Output* const output) {
  if (visited->contains(info.absoluteFilePath())) return;
  *visited << info.absoluteFilePath();
  if (info.isDir()) {
    QDir dir(info.absoluteFilePath());
    for (const QFileInfo& entry : dir.entryInfoList(
             QStringList() << "*.jxl",
             QDir::Files | QDir::AllDirs | QDir::NoDotAndDotDot)) {
      recursivelyAddSubEntries(entry, visited, output);
    }
  } else {
    *output << info.absoluteFilePath();
  }
}

}  // namespace

ViewerWindow::ViewerWindow(QWidget* const parent)
    : QMainWindow(parent), monitorProfile_(GetMonitorIccProfile(this)) {
  ui_.setupUi(this);
  ui_.actionOpen->setShortcut(QKeySequence::Open);
  ui_.actionExit->setShortcut(QKeySequence::Quit);
}

void ViewerWindow::loadFilesAndDirectories(QStringList entries) {
  filenames_.clear();
  QSet<QString> visited;
  for (const QString& entry : entries) {
    recursivelyAddSubEntries(QFileInfo(entry), &visited, &filenames_);
  }

  const bool several = filenames_.size() > 1;
  ui_.actionPreviousImage->setEnabled(several);
  ui_.actionNextImage->setEnabled(several);

  currentFileIndex_ = 0;
  refreshImage();
}

void ViewerWindow::on_actionOpen_triggered() {
  QFileDialog dialog(this, tr("Select JPEG XL files to open…"));
  dialog.setFileMode(QFileDialog::ExistingFiles);
  dialog.setNameFilter(tr("JPEG XL images (*.jxl);;All files (*)"));
  if (dialog.exec()) {
    loadFilesAndDirectories(dialog.selectedFiles());
  }
}

void ViewerWindow::on_actionPreviousImage_triggered() {
  currentFileIndex_ =
      (currentFileIndex_ - 1 + filenames_.size()) % filenames_.size();
  refreshImage();
}

void ViewerWindow::on_actionNextImage_triggered() {
  currentFileIndex_ = (currentFileIndex_ + 1) % filenames_.size();
  refreshImage();
}

void ViewerWindow::refreshImage() {
  if (currentFileIndex_ < 0 || currentFileIndex_ >= filenames_.size()) {
    return;
  }

  qint64 elapsed_ns;
  bool usedRequestedProfile;
  const QImage image =
      loadJxlImage(filenames_[currentFileIndex_], monitorProfile_, &elapsed_ns,
                   &usedRequestedProfile);
  if (image.isNull()) {
    const QString message =
        tr("Failed to load \"%1\".").arg(filenames_[currentFileIndex_]);
    ui_.image->clear();
    ui_.statusBar->showMessage(message);
    QMessageBox errorDialog(this);
    errorDialog.setIcon(QMessageBox::Critical);
    errorDialog.setWindowTitle(tr("Failed to load image"));
    errorDialog.setText(message);
    errorDialog.exec();
    return;
  }

  ui_.image->setPixmap(QPixmap::fromImage(image));
  ui_.statusBar->showMessage(
      tr("Loaded image %L1/%L2 (%3, %4×%5) in %L6ms (%L7 fps)")
          .arg(currentFileIndex_ + 1)
          .arg(filenames_.size())
          .arg(filenames_[currentFileIndex_])
          .arg(image.width())
          .arg(image.height())
          .arg(elapsed_ns / 1e6)
          .arg(1e9 / elapsed_ns));

  if (!usedRequestedProfile && !hasWarnedAboutMonitorProfile_) {
    hasWarnedAboutMonitorProfile_ = true;
    QMessageBox message(this);
    message.setIcon(QMessageBox::Warning);
    message.setWindowTitle(tr("No valid monitor profile found"));
    message.setText(
        tr("Failed to find a usable monitor profile. Images will be shown "
           "assuming that the monitor's colorspace is sRGB."));
    message.exec();
  }
}

}  // namespace tools
}  // namespace jpegxl
