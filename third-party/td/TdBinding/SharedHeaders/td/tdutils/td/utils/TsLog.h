//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"
#include "td/utils/logging.h"
#include "td/utils/Slice.h"

#include <atomic>

namespace td {

class TsLog final : public LogInterface {
 public:
  explicit TsLog(LogInterface *log) : log_(log) {
  }
  void init(LogInterface *log) {
    enter_critical();
    log_ = log;
    exit_critical();
  }
  void after_rotation() final {
    enter_critical();
    log_->after_rotation();
    exit_critical();
  }
  vector<string> get_file_paths() final {
    enter_critical();
    auto result = log_->get_file_paths();
    exit_critical();
    return result;
  }

 private:
  void do_append(int log_level, CSlice slice) final {
    enter_critical();
    log_->do_append(log_level, slice);
    exit_critical();
  }

  void enter_critical();

  void exit_critical() {
    lock_.clear(std::memory_order_release);
  }

  LogInterface *log_ = nullptr;
  std::atomic_flag lock_ = ATOMIC_FLAG_INIT;
};

}  // namespace td
