//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/algorithm.h"
#include "td/utils/common.h"
#include "td/utils/logging.h"
#include "td/utils/Slice.h"

namespace td {

class CombinedLog final : public LogInterface {
 public:
  void set_first(LogInterface *first) {
    first_ = first;
  }

  void set_second(LogInterface *second) {
    second_ = second;
  }

  void set_first_verbosity_level(int new_verbosity_level) {
    first_verbosity_level_ = new_verbosity_level;
  }

  void set_second_verbosity_level(int new_verbosity_level) {
    second_verbosity_level_ = new_verbosity_level;
  }

  const LogInterface *get_first() const {
    return first_;
  }

  const LogInterface *get_second() const {
    return second_;
  }

  int get_first_verbosity_level() const {
    return first_verbosity_level_;
  }

  int get_second_verbosity_level() const {
    return second_verbosity_level_;
  }

 private:
  LogInterface *first_ = nullptr;
  int first_verbosity_level_ = VERBOSITY_NAME(FATAL);
  LogInterface *second_ = nullptr;
  int second_verbosity_level_ = VERBOSITY_NAME(FATAL);

  void do_append(int log_level, CSlice slice) final {
    if (first_ && log_level <= first_verbosity_level_) {
      first_->do_append(log_level, slice);
    }
    if (second_ && log_level <= second_verbosity_level_) {
      second_->do_append(log_level, slice);
    }
  }

  void after_rotation() final {
    if (first_) {
      first_->after_rotation();
    }
    if (second_) {
      second_->after_rotation();
    }
  }

  vector<string> get_file_paths() final {
    vector<string> result;
    if (first_) {
      ::td::append(result, first_->get_file_paths());
    }
    if (second_) {
      ::td::append(result, second_->get_file_paths());
    }
    return result;
  }
};

}  // namespace td
