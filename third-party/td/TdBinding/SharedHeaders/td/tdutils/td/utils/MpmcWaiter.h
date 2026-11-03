//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"
#include "td/utils/logging.h"
#include "td/utils/port/sleep.h"

#include <algorithm>
#include <atomic>
#include <condition_variable>
#include <mutex>

namespace td {

class MpmcEagerWaiter {
 public:
  struct Slot {
    explicit Slot(uint32 worker_id) : yields(0), worker_id(worker_id) {
    }

   private:
    friend class MpmcEagerWaiter;
    int yields;
    uint32 worker_id;
  };

  void wait(Slot &slot) {
    if (slot.yields < RoundsTillSleepy) {
      yield();
      slot.yields++;
    } else if (slot.yields == RoundsTillSleepy) {
      auto state = state_.load(std::memory_order_relaxed);
      if (!State::has_worker(state)) {
        auto new_state = State::with_worker(state, slot.worker_id);
        if (state_.compare_exchange_strong(state, new_state, std::memory_order_acq_rel)) {
          yield();
          slot.yields++;
          return;
        }
        if (state == State::awake()) {
          slot.yields = 0;
          return;
        }
      }
      yield();
      slot.yields = 0;
    } else if (slot.yields < RoundsTillAsleep) {
      auto state = state_.load(std::memory_order_acquire);
      if (State::still_sleepy(state, slot.worker_id)) {
        yield();
        slot.yields++;
        return;
      }
      slot.yields = 0;
    } else {
      auto state = state_.load(std::memory_order_acquire);
      if (State::still_sleepy(state, slot.worker_id)) {
        std::unique_lock<std::mutex> lock(mutex_);
        if (state_.compare_exchange_strong(state, State::asleep(), std::memory_order_acq_rel)) {
          condition_variable_.wait(lock);
        }
      }
      slot.yields = 0;
    }
  }

  void stop_wait(Slot &slot) {
    if (slot.yields > RoundsTillSleepy) {
      notify_cold();
    }
    slot.yields = 0;
  }

  void close() {
  }

  void notify() {
    std::atomic_thread_fence(std::memory_order_seq_cst);
    if (state_.load(std::memory_order_acquire) == State::awake()) {
      return;
    }
    notify_cold();
  }

 private:
  struct State {
    static constexpr uint32 awake() {
      return 0;
    }
    static constexpr uint32 asleep() {
      return 1;
    }
    static bool is_asleep(uint32 state) {
      return (state & 1) != 0;
    }
    static bool has_worker(uint32 state) {
      return (state >> 1) != 0;
    }
    static int32 with_worker(uint32 state, uint32 worker) {
      return state | ((worker + 1) << 1);
    }
    static bool still_sleepy(uint32 state, uint32 worker) {
      return (state >> 1) == (worker + 1);
    }
  };
  enum { RoundsTillSleepy = 32, RoundsTillAsleep = 64 };
  // enum { RoundsTillSleepy = 1, RoundsTillAsleep = 2 };
  std::atomic<uint32> state_{State::awake()};
  std::mutex mutex_;
  std::condition_variable condition_variable_;

  void notify_cold() {
    auto old_state = state_.exchange(State::awake(), std::memory_order_release);
    if (State::is_asleep(old_state)) {
      std::lock_guard<std::mutex> guard(mutex_);
      condition_variable_.notify_all();
    }
  }
  static void yield() {
    // whatever, this is better than sched_yield
    usleep_for(1);
  }
};

class MpmcSleepyWaiter {
 public:
  struct Slot {
   private:
    friend class MpmcSleepyWaiter;

    enum State { Search, Work, Sleep } state_{Work};

    void park() {
      std::unique_lock<std::mutex> guard(mutex_);
      condition_variable_.wait(guard, [&] { return unpark_flag_; });
      unpark_flag_ = false;
    }

    bool cancel_park() {
      auto res = unpark_flag_;
      unpark_flag_ = false;
      return res;
    }

    void unpark() {
      //TODO: try to unlock guard before notify_all
      std::unique_lock<std::mutex> guard(mutex_);
      unpark_flag_ = true;
      condition_variable_.notify_all();
    }

    std::mutex mutex_;
    std::condition_variable condition_variable_;
    bool unpark_flag_{false};  // TODO: move out of lock
    int yield_cnt{0};
    int32 worker_id{0};

   public:
    char padding[TD_CONCURRENCY_PAD];

    explicit Slot(int32 worker_id) : state_(State::Work), worker_id(worker_id) {
      VLOG(waiter) << "Init slot " << worker_id;
    }
  };

  // There are a lot of workers
  // Each has a slot
  //
  // States of a worker:
  //   - searching for work | Search
  //   - processing work    | Work
  //   - sleeping           | Sleep
  //
  // When somebody adds a work it calls notify
  //
  // notify
  //   if there are workers in search phase do nothing.
  //   if all workers are awake do nothing
  //   otherwise wake some random worker
  //
  // Initially all workers are in Search mode.
  //
  // When worker found nothing it may try to call wait.
  // This may put it in a Sleep for some time.
  // After wait returns worker will be in Search state again.
  //
  // If a worker found a work and ready to process it, then it may call stop_wait.
  // This will cause transition from Search to Work state.
  //
  // Main invariant:
  // After notify is called there should be at least on worker in Search or Work state.
  // If possible - in Search state
  //

  static constexpr int VERBOSITY_NAME(waiter) = VERBOSITY_NAME(DEBUG) + 10;
  void wait(Slot &slot) {
    if (slot.state_ == Slot::State::Work) {
      VLOG(waiter) << "Work -> Search";
      state_++;
      slot.state_ = Slot::State::Search;
      slot.yield_cnt = 0;
      return;
    }
    if (slot.state_ == Slot::Search) {
      if (slot.yield_cnt++ < 10 && false) {
        // TODO some sleep backoff is possible
        return;
      }

      slot.state_ = Slot::State::Sleep;
      std::unique_lock<std::mutex> guard(sleepers_mutex_);
      auto state_view = StateView(state_.fetch_add((1 << PARKING_SHIFT) - 1));
      CHECK(state_view.searching_count != 0);
      bool should_search = state_view.searching_count == 1;
      if (closed_) {
        return;
      }
      sleepers_.push_back(&slot);
      LOG_CHECK(!slot.unpark_flag_) << slot.worker_id;
      VLOG(waiter) << "Add to sleepers " << slot.worker_id;
      //guard.unlock();
      if (should_search) {
        VLOG(waiter) << "Search -> Search once, then Sleep ";
        return;
      }
      VLOG(waiter) << "Search -> Sleep " << state_view.searching_count << " " << state_view.parked_count;
    }

    CHECK(slot.state_ == Slot::State::Sleep);
    VLOG(waiter) << "Park " << slot.worker_id;
    slot.park();
    VLOG(waiter) << "Resume " << slot.worker_id;
    slot.state_ = Slot::State::Search;
    slot.yield_cnt = 0;
  }

  void stop_wait(Slot &slot) {
    if (slot.state_ == Slot::State::Work) {
      return;
    }
    if (slot.state_ == Slot::State::Sleep) {
      VLOG(waiter) << "Search once, then Sleep -> Work/Search " << slot.worker_id;
      slot.state_ = Slot::State::Work;
      std::unique_lock<std::mutex> guard(sleepers_mutex_);
      auto it = std::find(sleepers_.begin(), sleepers_.end(), &slot);
      if (it != sleepers_.end()) {
        sleepers_.erase(it);
        VLOG(waiter) << "Remove from sleepers " << slot.worker_id;
        state_.fetch_sub((1 << PARKING_SHIFT) - 1);
        guard.unlock();
      } else {
        guard.unlock();
        VLOG(waiter) << "Not in sleepers " << slot.worker_id;
        CHECK(slot.cancel_park());
      }
    }
    VLOG(waiter) << "Search once, then Sleep -> Work " << slot.worker_id;
    slot.state_ = Slot::State::Search;
    auto state_view = StateView(state_.fetch_sub(1));
    CHECK(state_view.searching_count != 0);
    CHECK(state_view.searching_count < 1000);
    bool should_notify = state_view.searching_count == 1;
    if (should_notify) {
      VLOG(waiter) << "Notify others";
      notify();
    }
    VLOG(waiter) << "Search -> Work ";
    slot.state_ = Slot::State::Work;
  }

  void notify() {
    auto view = StateView(state_.load());
    //LOG(ERROR) << view.parked_count;
    if (view.searching_count > 0 || view.parked_count == 0) {
      VLOG(waiter) << "Ignore notify: " << view.searching_count << ' ' << view.parked_count;
      return;
    }

    VLOG(waiter) << "Notify: " << view.searching_count << ' ' << view.parked_count;
    std::unique_lock<std::mutex> guard(sleepers_mutex_);

    view = StateView(state_.load());
    if (view.searching_count > 0) {
      VLOG(waiter) << "Skip notify: search is active";
      return;
    }

    CHECK(view.parked_count == static_cast<int>(sleepers_.size()));
    if (sleepers_.empty()) {
      VLOG(waiter) << "Skip notify: no sleepers";
      return;
    }

    auto sleeper = sleepers_.back();
    sleepers_.pop_back();
    state_.fetch_sub((1 << PARKING_SHIFT) - 1);
    VLOG(waiter) << "Unpark " << sleeper->worker_id;
    sleeper->unpark();
  }

  void close() {
    StateView state(state_.load());
    LOG_CHECK(state.parked_count == 0) << state.parked_count;
    LOG_CHECK(state.searching_count == 0) << state.searching_count;
  }

 private:
  static constexpr int32 PARKING_SHIFT = 16;
  struct StateView {
    int32 parked_count;
    int32 searching_count;
    explicit StateView(int32 x) {
      parked_count = x >> PARKING_SHIFT;
      searching_count = x & ((1 << PARKING_SHIFT) - 1);
    }
  };
  std::atomic<int32> state_{0};

  std::mutex sleepers_mutex_;
  vector<Slot *> sleepers_;

  bool closed_ = false;
};

using MpmcWaiter = MpmcSleepyWaiter;

}  // namespace td
