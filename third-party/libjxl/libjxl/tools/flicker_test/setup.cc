// Copyright (c) the JPEG XL Project Authors. All rights reserved.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

#include "tools/flicker_test/setup.h"

#include <QCompleter>
#include <QFileDialog>
#include <QFileSystemModel>
#include <QMessageBox>
#include <QPushButton>

namespace jpegxl {
namespace tools {

FlickerTestWizard::FlickerTestWizard(QWidget* const parent)
    : QWizard(parent), settings_("JPEG XL project", "Flickering test") {
  ui_.setupUi(this);

  connect(ui_.grayFadingTime, SIGNAL(valueChanged(int)), this,
          SLOT(updateTotalGrayTime()));
  connect(ui_.grayTime, SIGNAL(valueChanged(int)), this,
          SLOT(updateTotalGrayTime()));

  ui_.timingButtonBox->button(QDialogButtonBox::RestoreDefaults)
      ->setText(tr("Restore ISO/IEC 29170-2:2015 parameters"));

  setButtonText(QWizard::FinishButton, tr("Start test"));

  QCompleter* const completer = new QCompleter(this);
  QFileSystemModel* const model = new QFileSystemModel(completer);
  model->setRootPath("/");
  model->setFilter(QDir::Dirs);
  completer->setModel(model);
  ui_.originalFolder->setCompleter(completer);
  ui_.alteredFolder->setCompleter(completer);

  const auto parameters = FlickerTestParameters::loadFrom(&settings_);
  ui_.originalFolder->setText(parameters.originalFolder);
  ui_.alteredFolder->setText(parameters.alteredFolder);
  ui_.outputFile->setText(parameters.outputFile);
  ui_.advanceTime->setValue(parameters.advanceTimeMSecs);
  ui_.viewingTime->setValue(parameters.viewingTimeSecs);
  ui_.blankingTime->setValue(parameters.blankingTimeMSecs);
  ui_.grayFlickering->setChecked(parameters.gray);
  ui_.grayFadingTime->setValue(parameters.grayFadingTimeMSecs);
  ui_.grayTime->setValue(parameters.grayTimeMSecs);
  ui_.intensityTarget->setValue(parameters.intensityTarget);
  ui_.spacing->setValue(parameters.spacing);

  QImage white(256, 256, QImage::Format_RGB32);
  white.fill(Qt::white);
  ui_.spacingDemo->setOriginalImage(white);
  ui_.spacingDemo->setAlteredImage(white);

  connect(this, &QDialog::accepted,
          [&] { this->parameters().saveTo(&settings_); });
}

FlickerTestParameters FlickerTestWizard::parameters() const {
  FlickerTestParameters result;
  result.originalFolder = ui_.originalFolder->text();
  result.alteredFolder = ui_.alteredFolder->text();
  result.outputFile = ui_.outputFile->text();
  result.advanceTimeMSecs = ui_.advanceTime->value();
  result.viewingTimeSecs = ui_.viewingTime->value();
  result.blankingTimeMSecs = ui_.blankingTime->value();
  result.gray = ui_.grayFlickering->isChecked();
  result.grayFadingTimeMSecs = ui_.grayFadingTime->value();
  result.grayTimeMSecs = ui_.grayTime->value();
  result.intensityTarget = ui_.intensityTarget->value();
  result.spacing = ui_.spacing->value();
  return result;
}

void FlickerTestWizard::on_originalFolderBrowseButton_clicked() {
  const QString path = QFileDialog::getExistingDirectory(
      this, tr("Folder with original images"), ui_.originalFolder->text());
  if (!path.isEmpty()) {
    ui_.originalFolder->setText(path);
  }
}

void FlickerTestWizard::on_alteredFolderBrowseButton_clicked() {
  const QString path = QFileDialog::getExistingDirectory(
      this, tr("Folder with altered images"), ui_.alteredFolder->text());
  if (!path.isEmpty()) {
    ui_.alteredFolder->setText(path);
  }
}

void FlickerTestWizard::on_outputFileBrowseButton_clicked() {
  // The overwrite check is disabled here because it is carried out in
  // `validateCurrentPage` (called when the user clicks the "Next" button) so
  // that it also applies to automatically-reloaded settings.
  const QString path = QFileDialog::getSaveFileName(
      this, tr("CSV file in which to save the results"), ui_.outputFile->text(),
      tr("CSV files (*.csv)"), /*selectedFilter=*/nullptr,
      QFileDialog::DontConfirmOverwrite);
  if (!path.isEmpty()) {
    ui_.outputFile->setText(path);
  }
}

void FlickerTestWizard::on_timingButtonBox_clicked(
    QAbstractButton* const button) {
  if (ui_.timingButtonBox->standardButton(button) ==
      QDialogButtonBox::RestoreDefaults) {
    ui_.advanceTime->setValue(100);
    ui_.viewingTime->setValue(4);
    ui_.blankingTime->setValue(250);
    ui_.grayFlickering->setChecked(false);
  }
}

void FlickerTestWizard::updateTotalGrayTime() {
  ui_.totalGrayTimeLabel->setText(
      tr("Total gray time: %L1&#8239;ms")
          .arg(2 * ui_.grayFadingTime->value() + ui_.grayTime->value()));
}

bool FlickerTestWizard::validateCurrentPage() {
  if (currentPage() == ui_.pathsPage && QFile::exists(ui_.outputFile->text())) {
    QMessageBox messageBox(this);
    messageBox.setIcon(QMessageBox::Warning);
    messageBox.setStandardButtons(QMessageBox::Ok | QMessageBox::Cancel);
    messageBox.setWindowTitle(tr("Output file already exists"));
    messageBox.setText(tr("The selected output file \"%1\" already exists.")
                           .arg(ui_.outputFile->text()));
    messageBox.setInformativeText(tr("Do you wish to overwrite it?"));
    if (messageBox.exec() == QMessageBox::Cancel) {
      return false;
    }
  } else if (currentPage() == ui_.timesPage) {
    if (ui_.grayFlickering->isChecked() &&
        2 * ui_.grayFadingTime->value() + ui_.grayTime->value() >
            ui_.advanceTime->value()) {
      QMessageBox messageBox(this);
      messageBox.setIcon(QMessageBox::Warning);
      messageBox.setStandardButtons(QMessageBox::Ok);
      messageBox.setWindowTitle(tr("Incompatible times selected"));
      messageBox.setText(
          tr("The total gray time is greater than the advance time."));
      messageBox.exec();
      return false;
    }
  }
  return QWizard::validateCurrentPage();
}

}  // namespace tools
}  // namespace jpegxl
