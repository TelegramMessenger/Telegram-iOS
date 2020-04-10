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
#include "td/utils/TimedStat.h"

namespace td {

class FloodControlFast {
 public:
  uint32 add_event(int32 now) {
    for (auto &limit : limits_) {
      limit.stat_.add_event(CounterStat::Event(), now);
      if (limit.stat_.get_stat(now).count_ > limit.count_) {
        wakeup_at_ = max(wakeup_at_, now + limit.duration_ * 2);
      }
    }
    return wakeup_at_;
  }
  uint32 get_wakeup_at() {
    return wakeup_at_;
  }

  void add_limit(uint32 duration, int32 count) {
    limits_.push_back({TimedStat<CounterStat>(duration, 0), duration, count});
  }

  void clear_events() {
    for (auto &limit : limits_) {
      limit.stat_.clear_events();
    }
    wakeup_at_ = 0;
  }

 private:
  class CounterStat {
   public:
    struct Event {};
    int32 count_ = 0;
    void on_event(Event e) {
      count_++;
    }
    void clear() {
      count_ = 0;
    }
  };

  uint32 wakeup_at_ = 0;
  struct Limit {
    TimedStat<CounterStat> stat_;
    uint32 duration_;
    int32 count_;
  };
  std::vector<Limit> limits_;
};

}  // namespace td
