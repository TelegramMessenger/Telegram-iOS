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
#include "td/utils/port/Clocks.h"

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
  static Timestamp at_unix(double timeout) {
    return Timestamp{timeout - td::Clocks::system() + Time::now()};
  }

  static Timestamp in(double timeout) {
    return Timestamp{Time::now_cached() + timeout};
  }

  bool is_in_past() const {
    return at_ <= Time::now_cached();
  }

  explicit operator bool() const {
    return at_ > 0;
  }

  double at() const {
    return at_;
  }
  double at_unix() const {
    return at_ + Clocks::system() - Time::now();
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

template <class StorerT>
void store(const Timestamp &timestamp, StorerT &storer) {
  storer.store_binary(timestamp.at() - Time::now() + Clocks::system());
}

template <class ParserT>
void parse(Timestamp &timestamp, ParserT &parser) {
  timestamp = Timestamp::in(parser.fetch_double() - Clocks::system());
}

}  // namespace td
