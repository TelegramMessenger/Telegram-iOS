/*
    This file is part of TON Blockchain Library.

    TON Blockchain Library is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser General Public License as published by
    the Free Software Foundation, either version 2 of the License, or
    (at your option) any later version.

    TON Blockchain Library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public License
    along with TON Blockchain Library.  If not, see <http://www.gnu.org/licenses/>.

    Copyright 2017-2020 Telegram Systems LLP
*/
#include "td/utils/FileLog.h"

#include "td/utils/common.h"
#include "td/utils/logging.h"
#include "td/utils/port/FileFd.h"
#include "td/utils/port/path.h"
#include "td/utils/port/StdStreams.h"
#include "td/utils/Slice.h"

#include <limits>

namespace td {

Status FileLog::init(string path, int64 rotate_threshold, bool redirect_stderr) {
  if (path == path_) {
    set_rotate_threshold(rotate_threshold);
    return Status::OK();
  }
  if (path.empty()) {
    return Status::Error("Log file path can't be empty");
  }

  TRY_RESULT(fd, FileFd::open(path, FileFd::Create | FileFd::Write | FileFd::Append));

  fd_.close();
  fd_ = std::move(fd);
  if (!Stderr().empty() && redirect_stderr) {
    fd_.get_native_fd().duplicate(Stderr().get_native_fd()).ignore();
  }

  auto r_path = realpath(path, true);
  if (r_path.is_error()) {
    path_ = std::move(path);
  } else {
    path_ = r_path.move_as_ok();
  }
  TRY_RESULT(size, fd_.get_size());
  size_ = size;
  rotate_threshold_ = rotate_threshold;
  redirect_stderr_ = redirect_stderr;
  return Status::OK();
}

Slice FileLog::get_path() const {
  return path_;
}

vector<string> FileLog::get_file_paths() {
  vector<string> result;
  if (!path_.empty()) {
    result.push_back(path_);
    result.push_back(PSTRING() << path_ << ".old");
  }
  return result;
}

void FileLog::set_rotate_threshold(int64 rotate_threshold) {
  rotate_threshold_ = rotate_threshold;
}

int64 FileLog::get_rotate_threshold() const {
  return rotate_threshold_;
}

void FileLog::append(CSlice cslice, int log_level) {
  Slice slice = cslice;
  while (!slice.empty()) {
    auto r_size = fd_.write(slice);
    if (r_size.is_error()) {
      process_fatal_error(PSLICE() << r_size.error() << " in " << __FILE__ << " at " << __LINE__);
    }
    auto written = r_size.ok();
    size_ += static_cast<int64>(written);
    slice.remove_prefix(written);
  }
  if (log_level == VERBOSITY_NAME(FATAL)) {
    process_fatal_error(cslice);
  }

  if (size_ > rotate_threshold_) {
    auto status = rename(path_, PSLICE() << path_ << ".old");
    if (status.is_error()) {
      process_fatal_error(PSLICE() << status.error() << " in " << __FILE__ << " at " << __LINE__);
    }
    do_rotate();
  }
}

void FileLog::rotate() {
  if (path_.empty()) {
    return;
  }
  do_rotate();
}

void FileLog::do_rotate() {
  auto current_verbosity_level = GET_VERBOSITY_LEVEL();
  SET_VERBOSITY_LEVEL(std::numeric_limits<int>::min());  // to ensure that nothing will be printed to the closed log
  CHECK(!path_.empty());
  fd_.close();
  auto r_fd = FileFd::open(path_, FileFd::Create | FileFd::Truncate | FileFd::Write);
  if (r_fd.is_error()) {
    process_fatal_error(PSLICE() << r_fd.error() << " in " << __FILE__ << " at " << __LINE__);
  }
  fd_ = r_fd.move_as_ok();
  if (!Stderr().empty() && redirect_stderr_) {
    fd_.get_native_fd().duplicate(Stderr().get_native_fd()).ignore();
  }
  size_ = 0;
  SET_VERBOSITY_LEVEL(current_verbosity_level);
}

Result<td::unique_ptr<LogInterface>> FileLog::create(string path, int64 rotate_threshold, bool redirect_stderr) {
  auto l = make_unique<FileLog>();
  TRY_STATUS(l->init(std::move(path), rotate_threshold, redirect_stderr));
  return std::move(l);
}

}  // namespace td
