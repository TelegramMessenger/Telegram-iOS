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

    Copyright 2017-2019 Telegram Systems LLP
*/
#pragma once

#include "td/utils/common.h"

#include <limits>

namespace td {

// More strict implementaions of flood control than FloodControlFast.
// Should be just fine for small counters.
class FloodControlStrict {
 public:
  int32 add_event(int32 now) {
    events_.push_back(Event{now});
    if (without_update_ > 0) {
      without_update_--;
    } else {
      update(now);
    }
    return wakeup_at_;
  }

  // no more than count in each duration.
  void add_limit(int32 duration, int32 count) {
    limits_.push_back(Limit{duration, count, 0});
  }

  int32 get_wakeup_at() {
    return wakeup_at_;
  }

  void clear_events() {
    events_.clear();
    for (auto &limit : limits_) {
      limit.pos_ = 0;
    }
    without_update_ = 0;
    wakeup_at_ = 0;
  }

  int32 update(int32 now) {
    size_t min_pos = events_.size();

    without_update_ = std::numeric_limits<size_t>::max();
    for (auto &limit : limits_) {
      if (limit.pos_ + limit.count_ < events_.size()) {
        limit.pos_ = events_.size() - limit.count_;
      }

      // binary-search? :D
      while (limit.pos_ < events_.size() && events_[limit.pos_].timestamp_ + limit.duration_ < now) {
        limit.pos_++;
      }

      if (limit.count_ + limit.pos_ <= events_.size()) {
        CHECK(limit.count_ + limit.pos_ == events_.size());
        wakeup_at_ = max(wakeup_at_, events_[limit.pos_].timestamp_ + limit.duration_);
        without_update_ = 0;
      } else {
        without_update_ = min(without_update_, limit.count_ + limit.pos_ - events_.size());
      }

      min_pos = min(min_pos, limit.pos_);
    }

    if (min_pos * 2 > events_.size()) {
      for (auto &limit : limits_) {
        limit.pos_ -= min_pos;
      }
      events_.erase(events_.begin(), events_.begin() + min_pos);
    }
    return wakeup_at_;
  }

 private:
  int32 wakeup_at_ = 0;
  struct Event {
    int32 timestamp_;
  };
  struct Limit {
    int32 duration_;
    int32 count_;
    size_t pos_;
  };
  size_t without_update_ = 0;
  std::vector<Event> events_;
  std::vector<Limit> limits_;
};

}  // namespace td
