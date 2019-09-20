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

#include "td/actor/core/ActorSignals.h"
#include "td/actor/core/ActorState.h"

#include "td/utils/logging.h"

#include <atomic>

namespace td {
namespace actor {
namespace core {
class ActorLocker {
 public:
  struct Options {
    Options() {
    }
    bool can_execute_paused = false;
    bool is_shared = true;
    SchedulerId scheduler_id;

    Options &with_can_execute_paused(bool new_can_execute_paused) {
      can_execute_paused = new_can_execute_paused;
      return *this;
    }
    Options &with_is_shared(bool new_is_shared) {
      is_shared = new_is_shared;
      return *this;
    }
    Options &with_scheduler_id(SchedulerId id) {
      scheduler_id = id;
      return *this;
    }
  };
  explicit ActorLocker(ActorState *state, Options options = {})
      : state_(state), flags_(state->get_flags_unsafe()), new_flags_{}, options_{options} {
  }
  bool try_lock() {
    CHECK(!own_lock());
    while (!can_try_add_signals()) {
      new_flags_ = flags_;
      new_flags_.set_locked(true);
      new_flags_.clear_signals();
      if (state_->state_.compare_exchange_strong(flags_.raw_ref(), new_flags_.raw(), std::memory_order_acq_rel)) {
        own_lock_ = true;
        return true;
      }
    }
    return false;
  }
  bool try_unlock(ActorState::Flags flags) {
    CHECK(!flags.is_locked());
    CHECK(own_lock());
    // can't unlock with signals set
    //CHECK(!flags.has_signals());

    flags_ = flags;
    // try to unlock
    if (state_->state_.compare_exchange_strong(new_flags_.raw_ref(), flags.raw(), std::memory_order_acq_rel)) {
      own_lock_ = false;
      return true;
    }

    // read all signals
    flags.set_locked(true);
    flags.clear_signals();
    do {
      flags_.add_signals(new_flags_.get_signals());
    } while (!state_->state_.compare_exchange_strong(new_flags_.raw_ref(), flags.raw(), std::memory_order_acq_rel));
    new_flags_ = flags;
    return false;
  }

  bool try_add_signals(ActorSignals signals) {
    CHECK(!own_lock());
    CHECK(can_try_add_signals());
    new_flags_ = flags_;
    new_flags_.add_signals(signals);

    // This is not an optimization.
    // Sometimes it helps sometimes it makes things worse
    // It there are a lot of threads concurrently sending signals to an actor it helps
    // Buf it threre is only one thread, CAS without conficts is much cheaper than full
    // barrier.
    if (false && flags_.raw() == new_flags_.raw()) {
      std::atomic_thread_fence(std::memory_order_seq_cst);
      auto actual_flags = state_->get_flags_unsafe();
      if (actual_flags.raw() == new_flags_.raw()) {
        return true;
      }
    }

    return state_->state_.compare_exchange_strong(flags_.raw_ref(), new_flags_.raw(), std::memory_order_acq_rel);
  }
  bool add_signals(ActorSignals signals) {
    CHECK(!own_lock());
    while (true) {
      if (can_try_add_signals()) {
        if (try_add_signals(signals)) {
          return false;
        }
      } else {
        if (try_lock()) {
          flags_.add_signals(signals);
          return true;
        }
      }
    }
  }
  bool own_lock() const {
    return own_lock_;
  }
  ActorState::Flags flags() const {
    return flags_;
  }
  bool can_execute() const {
    return flags_.is_shared() == options_.is_shared && flags_.get_scheduler_id() == options_.scheduler_id &&
           (options_.can_execute_paused || !flags_.get_signals().has_signal(ActorSignals::Pause));
  }

 private:
  ActorState *state_{nullptr};
  ActorState::Flags flags_;
  ActorState::Flags new_flags_;
  bool own_lock_{false};
  Options options_;

  bool can_try_add_signals() const {
    return flags_.is_locked() || (flags_.is_in_queue() && !can_execute());
  }
};
}  // namespace core
}  // namespace actor
}  // namespace td
