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
#include "td/utils/Timer.h"

#include "td/utils/format.h"
#include "td/utils/logging.h"
//#include  "td/utils/Slice.h"  // TODO move StringBuilder implementation to cpp, remove header
#include "td/utils/Time.h"

namespace td {

Timer::Timer(bool is_paused) : is_paused_(is_paused) {
  if (is_paused_) {
    start_time_ = 0;
  } else {
    start_time_ = Time::now();
  }
}

void Timer::pause() {
  if (is_paused_) {
    return;
  }
  elapsed_ += Time::now() - start_time_;
  is_paused_ = true;
}

void Timer::resume() {
  if (!is_paused_) {
    return;
  }
  start_time_ = Time::now();
  is_paused_ = false;
}

double Timer::elapsed() const {
  double res = elapsed_;
  if (!is_paused_) {
    res += Time::now() - start_time_;
  }
  return res;
}

StringBuilder &operator<<(StringBuilder &string_builder, const Timer &timer) {
  return string_builder << format::as_time(timer.elapsed());
}

PerfWarningTimer::PerfWarningTimer(string name, double max_duration)
    : name_(std::move(name)), start_at_(Time::now()), max_duration_(max_duration) {
}

PerfWarningTimer::PerfWarningTimer(PerfWarningTimer &&other)
    : name_(std::move(other.name_)), start_at_(other.start_at_), max_duration_(other.max_duration_) {
  other.start_at_ = 0;
}

PerfWarningTimer::~PerfWarningTimer() {
  reset();
}

void PerfWarningTimer::reset() {
  if (start_at_ == 0) {
    return;
  }
  double duration = Time::now() - start_at_;
  LOG_IF(WARNING, duration > max_duration_)
      << "SLOW: " << tag("name", name_) << tag("duration", format::as_time(duration));
  start_at_ = 0;
}

}  // namespace td
