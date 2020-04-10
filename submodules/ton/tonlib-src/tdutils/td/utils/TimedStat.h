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

#include "td/utils/common.h"

#include <utility>

namespace td {

template <class StatT>
class TimedStat {
 public:
  TimedStat(double duration, double now)
      : duration_(duration), current_(), current_timestamp_(now), next_(), next_timestamp_(now) {
  }
  TimedStat() : TimedStat(0, 0) {
  }
  template <class EventT>
  void add_event(const EventT &e, double now) {
    update(now);
    current_.on_event(e);
    next_.on_event(e);
  }
  const StatT &get_stat(double now) {
    update(now);
    return current_;
  }
  std::pair<StatT, double> stat_duration(double now) {
    update(now);
    return std::make_pair(current_, now - current_timestamp_);
  }
  void clear_events() {
    current_.clear();
    next_.clear();
  }

 private:
  double duration_;
  StatT current_;
  double current_timestamp_;
  StatT next_;
  double next_timestamp_;

  void update(double &now) {
    if (now < next_timestamp_) {
      // LOG_CHECK(now >= next_timestamp_ * (1 - 1e-14)) << now << " " << next_timestamp_;
      now = next_timestamp_;
    }
    if (duration_ == 0) {
      return;
    }
    if (next_timestamp_ + 2 * duration_ < now) {
      current_ = StatT();
      current_timestamp_ = now;
      next_ = StatT();
      next_timestamp_ = now;
    } else if (next_timestamp_ + duration_ < now) {
      current_ = next_;
      current_timestamp_ = next_timestamp_;
      next_ = StatT();
      next_timestamp_ = now;
    }
  }
};

}  // namespace td
