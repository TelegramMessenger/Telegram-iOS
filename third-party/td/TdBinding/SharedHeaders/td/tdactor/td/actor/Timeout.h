//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/actor/actor.h"

#include "td/utils/common.h"

namespace td {

class Timeout final : public Actor {
 public:
  using Data = void *;
  using Callback = void (*)(Data);
  Timeout() {
    register_actor("Timeout", this).release();
  }

  void set_callback(Callback callback) {
    callback_ = callback;
  }
  void set_callback_data(Data &&data) {
    data_ = data;
  }

  bool has_timeout() const {
    return Actor::has_timeout();
  }
  double get_timeout() const {
    return Actor::get_timeout();
  }
  void set_timeout_in(double timeout) {
    Actor::set_timeout_in(timeout);
  }
  void set_timeout_at(double timeout) {
    Actor::set_timeout_at(timeout);
  }
  void cancel_timeout() {
    if (has_timeout()) {
      Actor::cancel_timeout();
      callback_ = Callback();
      data_ = Data();
    }
  }

 private:
  friend class Scheduler;

  Callback callback_{};
  Data data_{};

  void timeout_expired() final {
    CHECK(!has_timeout());
    CHECK(callback_ != Callback());
    Callback callback = callback_;
    Data data = data_;
    callback_ = Callback();
    data_ = Data();

    callback(data);
  }
};

}  // namespace td
