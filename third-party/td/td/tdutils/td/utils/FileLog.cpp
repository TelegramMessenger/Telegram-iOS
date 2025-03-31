//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/utils/FileLog.h"

#include "td/utils/common.h"
#include "td/utils/logging.h"
#include "td/utils/port/FileFd.h"
#include "td/utils/port/path.h"
#include "td/utils/port/StdStreams.h"
#include "td/utils/port/thread_local.h"
#include "td/utils/Slice.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/Time.h"

namespace td {

Status FileLog::init(string path, int64 rotate_threshold, bool redirect_stderr) {
  if (path.empty()) {
    return Status::Error("Log file path must be non-empty");
  }
  if (path == path_) {
    set_rotate_threshold(rotate_threshold);
    return Status::OK();
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
  TRY_RESULT_ASSIGN(size_, fd_.get_size());
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

bool FileLog::get_redirect_stderr() const {
  return redirect_stderr_;
}

void FileLog::do_append(int log_level, CSlice slice) {
  auto start_time = Time::now();
  if (size_ > rotate_threshold_ || want_rotate_.load(std::memory_order_relaxed)) {
    auto status = rename(path_, PSLICE() << path_ << ".old");
    if (status.is_error()) {
      process_fatal_error(PSLICE() << status << " in " << __FILE__ << " at " << __LINE__ << '\n');
    }
    do_after_rotation();
  }
  while (!slice.empty()) {
    if (redirect_stderr_) {
      while (has_log_guard()) {
        // spin
      }
    }
    auto r_size = fd_.write(slice);
    if (r_size.is_error()) {
      process_fatal_error(PSLICE() << r_size.error() << " in " << __FILE__ << " at " << __LINE__ << '\n');
    }
    auto written = r_size.ok();
    size_ += static_cast<int64>(written);
    slice.remove_prefix(written);
  }
  auto total_time = Time::now() - start_time;
  if (total_time >= 0.1 && log_level >= 1) {
    auto thread_id = get_thread_id();
    auto r_size = fd_.write(PSLICE() << "[ 2][t" << (0 <= thread_id && thread_id < 10 ? " " : "") << thread_id
                                     << "] !!! Previous logging took " << total_time << " seconds !!!\n");
    r_size.ignore();
  }
}

void FileLog::after_rotation() {
  if (path_.empty()) {
    return;
  }
  do_after_rotation();
}

void FileLog::lazy_rotate() {
  want_rotate_ = true;
}

void FileLog::do_after_rotation() {
  want_rotate_ = false;
  ScopedDisableLog disable_log;  // to ensure that nothing will be printed to the closed log
  CHECK(!path_.empty());
  fd_.close();
  auto r_fd = FileFd::open(path_, FileFd::Create | FileFd::Write | FileFd::Append);
  if (r_fd.is_error()) {
    process_fatal_error(PSLICE() << r_fd.error() << " in " << __FILE__ << " at " << __LINE__ << '\n');
  }
  fd_ = r_fd.move_as_ok();
  if (!Stderr().empty() && redirect_stderr_) {
    fd_.get_native_fd().duplicate(Stderr().get_native_fd()).ignore();
  }
  auto r_size = fd_.get_size();
  if (r_fd.is_error()) {
    process_fatal_error(PSLICE() << "Failed to get log size: " << r_fd.error() << " in " << __FILE__ << " at "
                                 << __LINE__ << '\n');
  }
  size_ = r_size.move_as_ok();
}

Result<unique_ptr<LogInterface>> FileLog::create(string path, int64 rotate_threshold, bool redirect_stderr) {
  auto l = make_unique<FileLog>();
  TRY_STATUS(l->init(std::move(path), rotate_threshold, redirect_stderr));
  return std::move(l);
}

}  // namespace td
