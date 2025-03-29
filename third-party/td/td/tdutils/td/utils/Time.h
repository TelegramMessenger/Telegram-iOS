//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"

namespace td {

class Time {
 public:
  static double now();
  static double now_cached() {
    // Temporary(?) use now in now_cached
    // Problem:
    //   thread A: check that now() > timestamp and notifies thread B
    //   thread B: must see that now() > timestamp()
    //
    //   now() and now_cached() must be monotonic
    //
    //   if a=now[_cached]() happens before b=now[_cached] than
    //     a <= b
    //
    // As an alternative we may say that now_cached is a thread local copy of now
    return now();
  }
  static double now_unadjusted();

  // Used for testing. After jump_in_future(at) is called, now() >= at.
  static void jump_in_future(double at);
};

inline void relax_timeout_at(double *timeout, double new_timeout) {
  if (new_timeout == 0) {
    return;
  }
  if (*timeout == 0 || new_timeout < *timeout) {
    *timeout = new_timeout;
  }
}

class Timestamp {
 public:
  Timestamp() = default;
  static Timestamp never() {
    return Timestamp{};
  }
  static Timestamp now() {
    return Timestamp{Time::now()};
  }
  static Timestamp now_cached() {
    return Timestamp{Time::now_cached()};
  }
  static Timestamp at(double timeout) {
    return Timestamp{timeout};
  }

  static Timestamp in(double timeout, Timestamp now = now_cached()) {
    return Timestamp{now.at() + timeout};
  }

  bool is_in_past(Timestamp now) const {
    return at_ <= now.at();
  }
  bool is_in_past() const {
    return is_in_past(now_cached());
  }

  explicit operator bool() const noexcept {
    return at_ > 0;
  }

  double at() const {
    return at_;
  }

  double in() const {
    return at_ - Time::now_cached();
  }

  void relax(const Timestamp &timeout) {
    if (!timeout) {
      return;
    }
    if (!*this || at_ > timeout.at_) {
      at_ = timeout.at_;
    }
  }

  friend bool operator==(Timestamp a, Timestamp b);

 private:
  double at_{0};

  explicit Timestamp(double timeout) : at_(timeout) {
  }
};

inline bool operator<(const Timestamp &a, const Timestamp &b) {
  return a.at() < b.at();
}

}  // namespace td
