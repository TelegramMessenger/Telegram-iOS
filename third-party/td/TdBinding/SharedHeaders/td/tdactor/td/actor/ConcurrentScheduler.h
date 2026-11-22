//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/actor/actor.h"

#include "td/utils/common.h"
#include "td/utils/port/thread.h"
#include "td/utils/Slice.h"
#include "td/utils/Time.h"

#if TD_PORT_WINDOWS
#include "td/utils/port/detail/Iocp.h"
#endif

#include <atomic>
#include <functional>
#include <mutex>
#include <utility>

namespace td {

class ConcurrentScheduler final : private Scheduler::Callback {
 public:
  explicit ConcurrentScheduler(int32 additional_thread_count, uint64 thread_affinity_mask = 0);

  void finish_async() {
    schedulers_[0]->finish();
  }

  void wakeup() {
    schedulers_[0]->wakeup();
  }

  SchedulerGuard get_main_guard() {
    return schedulers_[0]->get_guard();
  }

  SchedulerGuard get_send_guard() {
    return schedulers_.back()->get_const_guard();
  }

  void test_one_thread_run();

  bool is_finished() const {
    return is_finished_.load(std::memory_order_relaxed);
  }

#if TD_THREAD_UNSUPPORTED
  int get_scheduler_thread_id(int32 sched_id) {
    return 1;
  }
#else
  thread::id get_scheduler_thread_id(int32 sched_id);
#endif

  void start();

  bool run_main(double timeout) {
    return run_main(Timestamp::in(timeout));
  }
  bool run_main(Timestamp timeout);

  Timestamp get_main_timeout();
  static double emscripten_get_main_timeout();
  static void emscripten_clear_main_timeout();

  void finish();

  template <class ActorT, class... Args>
  ActorOwn<ActorT> create_actor_unsafe(int32 sched_id, Slice name, Args &&...args) {
#if TD_THREAD_UNSUPPORTED || TD_EVENTFD_UNSUPPORTED
    sched_id = 0;
#endif
    CHECK(0 <= sched_id && sched_id < static_cast<int32>(schedulers_.size()));
    auto guard = schedulers_[sched_id]->get_guard();
    return schedulers_[sched_id]->create_actor<ActorT>(name, std::forward<Args>(args)...);
  }

  template <class ActorT>
  ActorOwn<ActorT> register_actor_unsafe(int32 sched_id, Slice name, ActorT *actor) {
#if TD_THREAD_UNSUPPORTED || TD_EVENTFD_UNSUPPORTED
    sched_id = 0;
#endif
    CHECK(0 <= sched_id && sched_id < static_cast<int32>(schedulers_.size()));
    auto guard = schedulers_[sched_id]->get_guard();
    return schedulers_[sched_id]->register_actor<ActorT>(name, actor);
  }

 private:
  enum class State { Start, Run };
  State state_ = State::Start;
  std::mutex at_finish_mutex_;
  vector<std::function<void()>> at_finish_;  // can be used during destruction by Scheduler destructors
  vector<unique_ptr<Scheduler>> schedulers_;
  std::atomic<bool> is_finished_{false};
#if !TD_THREAD_UNSUPPORTED && !TD_EVENTFD_UNSUPPORTED
  vector<td::thread> threads_;
  uint64 thread_affinity_mask_ = 0;
#endif
#if TD_PORT_WINDOWS
  unique_ptr<detail::Iocp> iocp_;
  td::thread iocp_thread_;
#endif
  int32 extra_scheduler_ = 0;

  void on_finish() final;

  void register_at_finish(std::function<void()> f) final;
};

}  // namespace td
