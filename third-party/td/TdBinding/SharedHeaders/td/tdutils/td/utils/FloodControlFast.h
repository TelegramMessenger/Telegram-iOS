//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"

namespace td {

class FloodControlFast {
 public:
  void add_event(double now) {
    for (auto &bucket : buckets_) {
      bucket.add_event(now);
      wakeup_at_ = td::max(wakeup_at_, bucket.get_wakeup_at());
    }
  }

  double get_wakeup_at() const {
    return wakeup_at_;
  }

  void add_limit(double duration, double count) {
    buckets_.emplace_back(duration, count);
  }

  void clear_events() {
    for (auto &bucket : buckets_) {
      bucket.clear_events();
    }
    wakeup_at_ = 0;
  }

 private:
  class FloodControlBucket {
   public:
    FloodControlBucket(double duration, double count)
        : max_capacity_(count - 1), speed_(count / duration), volume_(max_capacity_) {
    }

    void add_event(double now, double size = 1) {
      CHECK(now >= wakeup_at_);
      update_volume(now);
      if (volume_ >= size) {
        volume_ -= size;
        return;
      }
      size -= volume_;
      volume_ = 0;
      wakeup_at_ = volume_at_ + size / speed_;
      volume_at_ = wakeup_at_;
    }

    double get_wakeup_at() const {
      return wakeup_at_;
    }

    void clear_events() {
      volume_ = max_capacity_;
      volume_at_ = 0;
      wakeup_at_ = 0;
    }

   private:
    const double max_capacity_{1};
    const double speed_{1};
    double volume_{1};

    double volume_at_{0};
    double wakeup_at_{0};

    void update_volume(double now) {
      CHECK(now >= volume_at_);
      auto passed = now - volume_at_;
      volume_ = td::min(volume_ + passed * speed_, max_capacity_);
      volume_at_ = now;
    }
  };

  double wakeup_at_ = 0;
  vector<FloodControlBucket> buckets_;
};

}  // namespace td
