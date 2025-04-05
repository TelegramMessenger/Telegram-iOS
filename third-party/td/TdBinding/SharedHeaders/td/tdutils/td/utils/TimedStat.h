//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"
#include "td/utils/optional.h"

#include <functional>
#include <utility>

namespace td {

template <class StatT>
class TimedStat {
 public:
  TimedStat(double duration, double now)
      : duration_(duration), current_(), current_timestamp_(now - 1), next_(), next_timestamp_(now) {
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
      current_timestamp_ = now - duration_;
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

namespace detail {
template <class T, class Cmp>
struct MinMaxStat {
  using Event = T;
  void on_event(Event event) {
    if (!best_ || Cmp()(event, best_.value())) {
      best_ = event;
    }
  }
  optional<T> get_stat() const {
    return best_.copy();
  }

 private:
  optional<T> best_;
};
}  // namespace detail

template <class T>
using MinStat = detail::MinMaxStat<T, std::less<void>>;

template <class T>
using MaxStat = detail::MinMaxStat<T, std::greater<void>>;

}  // namespace td
