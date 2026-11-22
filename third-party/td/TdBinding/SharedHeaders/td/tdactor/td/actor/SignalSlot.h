//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/actor/actor.h"

namespace td {

class Slot;

class Signal {
 public:
  void emit();

  explicit Signal(ActorId<Slot> slot_id) : slot_id_(std::move(slot_id)) {
  }

 private:
  ActorId<Slot> slot_id_;
};

class Slot final : public Actor {
 public:
  Slot() = default;
  Slot(const Slot &) = delete;
  Slot &operator=(const Slot &) = delete;
  Slot(Slot &&) = default;
  Slot &operator=(Slot &&) = default;
  ~Slot() final {
    close();
  }
  void set_event(EventFull &&event) {
    was_signal_ = false;
    event_ = std::move(event);
  }

  bool has_event() {
    return !event_.empty();
  }

  bool was_signal() {
    return was_signal_;
  }

  void clear_event() {
    event_.clear();
  }

  void close() {
    if (!empty()) {
      do_stop();
    }
  }

  void set_timeout_in(double timeout_in) {
    register_if_empty();
    Actor::set_timeout_in(timeout_in);
  }
  void set_timeout_at(double timeout_at) {
    register_if_empty();
    Actor::set_timeout_at(timeout_at);
  }

  friend class Signal;
  Signal get_signal() {
    register_if_empty();
    return Signal(actor_id(this));
  }
  ActorShared<> get_signal_new() {
    register_if_empty();
    return actor_shared(this);
  }

 private:
  bool was_signal_ = false;
  EventFull event_;

  void timeout_expired() final {
    signal();
  }

  void start_up() final {
    empty();
  }

  void register_if_empty() {
    if (empty()) {
      register_actor("Slot", this).release();
    }
  }

  // send event only once
  void signal() {
    if (!was_signal_) {
      was_signal_ = true;
      event_.try_emit_later();
    }
  }
  void hangup_shared() final {
    signal();
  }
};

inline void Signal::emit() {
  send_closure(slot_id_, &Slot::signal);
}

}  // namespace td
