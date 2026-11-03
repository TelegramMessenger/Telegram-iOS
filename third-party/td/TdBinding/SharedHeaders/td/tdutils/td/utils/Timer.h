//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"
#include "td/utils/StringBuilder.h"

namespace td {

class Timer {
 public:
  Timer() : Timer(false) {
  }
  explicit Timer(bool is_paused);

  double elapsed() const;

  void pause();

  void resume();

 private:
  friend StringBuilder &operator<<(StringBuilder &string_builder, const Timer &timer);

  double elapsed_{0};
  double start_time_{0};
  bool is_paused_{true};
};

class PerfWarningTimer {
 public:
  explicit PerfWarningTimer(string name, double max_duration = 0.1);
  PerfWarningTimer(const PerfWarningTimer &) = delete;
  PerfWarningTimer &operator=(const PerfWarningTimer &) = delete;
  PerfWarningTimer(PerfWarningTimer &&other) noexcept;
  PerfWarningTimer &operator=(PerfWarningTimer &&) = delete;
  ~PerfWarningTimer();
  void reset();

 private:
  string name_;
  double start_at_{0};
  double max_duration_{0};
};

}  // namespace td
