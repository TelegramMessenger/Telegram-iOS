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
#pragma once

#include "td/utils/StringBuilder.h"

namespace td {

class Timer {
 public:
  Timer() : Timer(false) {
  }
  explicit Timer(bool is_paused);
  Timer(const Timer &other) = default;
  Timer &operator=(const Timer &other) = default;

  double elapsed() const;
  void pause();
  void resume();

 private:
  friend StringBuilder &operator<<(StringBuilder &string_builder, const Timer &timer);

  double elapsed_{0};
  double start_time_;
  bool is_paused_{false};
};

class PerfWarningTimer {
 public:
  explicit PerfWarningTimer(string name, double max_duration = 0.1);
  PerfWarningTimer(const PerfWarningTimer &) = delete;
  PerfWarningTimer &operator=(const PerfWarningTimer &) = delete;
  PerfWarningTimer(PerfWarningTimer &&other);
  PerfWarningTimer &operator=(PerfWarningTimer &&) = delete;
  ~PerfWarningTimer();
  void reset();

 private:
  string name_;
  double start_at_{0};
  double max_duration_{0};
};

}  // namespace td
