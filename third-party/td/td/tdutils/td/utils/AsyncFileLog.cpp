//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/utils/AsyncFileLog.h"

#include "td/utils/port/FileFd.h"
#include "td/utils/port/path.h"
#include "td/utils/port/sleep.h"
#include "td/utils/port/StdStreams.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/Time.h"

namespace td {

#if !TD_THREAD_UNSUPPORTED

Status AsyncFileLog::init(string path, int64 rotate_threshold, bool redirect_stderr) {
  CHECK(path_.empty());
  CHECK(!path.empty());

  TRY_RESULT(fd, FileFd::open(path, FileFd::Create | FileFd::Write | FileFd::Append));
  if (!Stderr().empty() && redirect_stderr) {
    fd.get_native_fd().duplicate(Stderr().get_native_fd()).ignore();
  }

  auto r_path = realpath(path, true);
  if (r_path.is_error()) {
    path_ = std::move(path);
  } else {
    path_ = r_path.move_as_ok();
  }
  TRY_RESULT(size, fd.get_size());

  queue_ = td::make_unique<MpscPollableQueue<Query>>();
  queue_->init();

  logging_thread_ = td::thread(
      [queue = queue_.get(), fd = std::move(fd), path = path_, size, rotate_threshold, redirect_stderr]() mutable {
        auto after_rotation = [&] {
          fd.close();
          auto r_fd = FileFd::open(path, FileFd::Create | FileFd::Write | FileFd::Append);
          if (r_fd.is_error()) {
            process_fatal_error(PSLICE() << r_fd.error() << " in " << __FILE__ << " at " << __LINE__ << '\n');
          }
          fd = r_fd.move_as_ok();
          if (!Stderr().empty() && redirect_stderr) {
            fd.get_native_fd().duplicate(Stderr().get_native_fd()).ignore();
          }
          auto r_size = fd.get_size();
          if (r_fd.is_error()) {
            process_fatal_error(PSLICE() << "Failed to get log size: " << r_fd.error() << " in " << __FILE__ << " at "
                                         << __LINE__ << '\n');
          }
          size = r_size.move_as_ok();
        };
        auto append = [&](CSlice slice) {
          if (size > rotate_threshold) {
            auto status = rename(path, PSLICE() << path << ".old");
            if (status.is_error()) {
              process_fatal_error(PSLICE() << status << " in " << __FILE__ << " at " << __LINE__ << '\n');
            }
            after_rotation();
          }
          while (!slice.empty()) {
            if (redirect_stderr) {
              while (has_log_guard()) {
                // spin
              }
            }
            auto r_size = fd.write(slice);
            if (r_size.is_error()) {
              process_fatal_error(PSLICE() << r_size.error() << " in " << __FILE__ << " at " << __LINE__ << '\n');
            }
            auto written = r_size.ok();
            size += static_cast<int64>(written);
            slice.remove_prefix(written);
          }
        };

        while (true) {
          int ready_count = queue->reader_wait_nonblock();
          if (ready_count == 0) {
            queue->reader_get_event_fd().wait(1000);
            continue;
          }
          bool need_close = false;
          while (ready_count-- > 0) {
            Query query = queue->reader_get_unsafe();
            switch (query.type_) {
              case Query::Type::Log:
                append(query.data_);
                break;
              case Query::Type::AfterRotation:
                after_rotation();
                break;
              case Query::Type::Close:
                need_close = true;
                break;
              default:
                process_fatal_error("Invalid query type in AsyncFileLog");
            }
          }
          queue->reader_flush();

          if (need_close) {
            fd.close();
            break;
          }
        }
      });

  return Status::OK();
}

AsyncFileLog::~AsyncFileLog() {
  if (queue_ == nullptr) {
    return;
  }
  Query query;
  query.type_ = Query::Type::Close;
  queue_->writer_put(std::move(query));
  logging_thread_.join();
}

vector<string> AsyncFileLog::get_file_paths() {
  vector<string> result;
  if (!path_.empty()) {
    result.push_back(path_);
    result.push_back(PSTRING() << path_ << ".old");
  }
  return result;
}

void AsyncFileLog::after_rotation() {
  Query query;
  query.type_ = Query::Type::AfterRotation;
  if (queue_ == nullptr) {
    process_fatal_error("AsyncFileLog is not inited");
  }
  queue_->writer_put(std::move(query));
}

void AsyncFileLog::do_append(int log_level, CSlice slice) {
  Query query;
  query.data_ = slice.str();
  if (queue_ == nullptr) {
    process_fatal_error("AsyncFileLog is not inited");
  }
  queue_->writer_put(std::move(query));
  if (log_level == VERBOSITY_NAME(FATAL)) {
    // it is not thread-safe to join logging_thread_ there, so just wait for the log line to be printed
    auto end_time = Time::now() + 1.0;
    while (!queue_->is_empty() && Time::now() < end_time) {
      usleep_for(1000);
    }
    usleep_for(5000);  // allow some time for the log line to be actually printed
  }
}

#endif

}  // namespace td
