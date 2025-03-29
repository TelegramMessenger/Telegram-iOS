//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/actor/ConcurrentScheduler.h"

#include "td/utils/ExitGuard.h"
#include "td/utils/MpscPollableQueue.h"
#include "td/utils/port/thread_local.h"
#include "td/utils/ScopeGuard.h"

#include <memory>

namespace td {

ConcurrentScheduler::ConcurrentScheduler(int32 additional_thread_count, uint64 thread_affinity_mask) {
#if TD_THREAD_UNSUPPORTED || TD_EVENTFD_UNSUPPORTED
  additional_thread_count = 0;
#endif
  additional_thread_count++;
  std::vector<std::shared_ptr<MpscPollableQueue<EventFull>>> outbound(additional_thread_count);
#if !TD_THREAD_UNSUPPORTED && !TD_EVENTFD_UNSUPPORTED
  for (int32 i = 0; i < additional_thread_count; i++) {
    auto queue = std::make_shared<MpscPollableQueue<EventFull>>();
    queue->init();
    outbound[i] = queue;
  }
  thread_affinity_mask_ = thread_affinity_mask;
#endif

  // +1 for extra scheduler for IOCP and send_closure from unrelated threads
  // It will know about other schedulers
  // Other schedulers will have no idea about its existence
  extra_scheduler_ = 1;
#if TD_THREAD_UNSUPPORTED || TD_EVENTFD_UNSUPPORTED
  extra_scheduler_ = 0;
#endif

  schedulers_.resize(additional_thread_count + extra_scheduler_);
  for (int32 i = 0; i < additional_thread_count + extra_scheduler_; i++) {
    auto &sched = schedulers_[i];
    sched = make_unique<Scheduler>();

#if !TD_THREAD_UNSUPPORTED && !TD_EVENTFD_UNSUPPORTED
    if (i >= additional_thread_count) {
      auto queue = std::make_shared<MpscPollableQueue<EventFull>>();
      queue->init();
      outbound.push_back(std::move(queue));
    }
#endif

    sched->init(i, outbound, static_cast<Scheduler::Callback *>(this));
  }

#if TD_PORT_WINDOWS
  iocp_ = make_unique<detail::Iocp>();
  iocp_->init();
#endif

  state_ = State::Start;
}

void ConcurrentScheduler::test_one_thread_run() {
  do {
    for (auto &sched : schedulers_) {
      sched->run(Timestamp::now_cached());
    }
  } while (!is_finished_.load(std::memory_order_relaxed));
}

#if !TD_THREAD_UNSUPPORTED
thread::id ConcurrentScheduler::get_scheduler_thread_id(int32 sched_id) {
  auto thread_pos = static_cast<size_t>(sched_id - 1);
  CHECK(thread_pos < threads_.size());
  return threads_[thread_pos].get_id();
}
#endif

void ConcurrentScheduler::start() {
  CHECK(state_ == State::Start);
  is_finished_.store(false, std::memory_order_relaxed);
#if !TD_THREAD_UNSUPPORTED && !TD_EVENTFD_UNSUPPORTED
  for (size_t i = 1; i + extra_scheduler_ < schedulers_.size(); i++) {
    auto &sched = schedulers_[i];
    threads_.push_back(td::thread([&, thread_affinity_mask = thread_affinity_mask_] {
#if TD_PORT_WINDOWS
      detail::Iocp::Guard iocp_guard(iocp_.get());
#endif
#if TD_HAVE_THREAD_AFFINITY
      if (thread_affinity_mask != 0) {
        thread::set_affinity_mask(this_thread::get_id(), thread_affinity_mask).ignore();
      }
#else
      (void)thread_affinity_mask;
#endif
      while (!is_finished()) {
        sched->run(Timestamp::in(10));
      }
    }));
  }
#if TD_PORT_WINDOWS
  iocp_thread_ = td::thread([this] {
    auto guard = this->get_send_guard();
    this->iocp_->loop();
  });
#endif
#endif

  state_ = State::Run;
}

static TD_THREAD_LOCAL double emscripten_timeout;

bool ConcurrentScheduler::run_main(Timestamp timeout) {
  CHECK(state_ == State::Run);
  // run main scheduler in same thread
  auto &main_sched = schedulers_[0];
  if (!is_finished()) {
#if TD_PORT_WINDOWS
    detail::Iocp::Guard iocp_guard(iocp_.get());
#endif
    main_sched->run(timeout);
  }

  // hack for emscripten
  emscripten_timeout = get_main_timeout().at();

  return !is_finished();
}

Timestamp ConcurrentScheduler::get_main_timeout() {
  CHECK(state_ == State::Run);
  return schedulers_[0]->get_timeout();
}

double ConcurrentScheduler::emscripten_get_main_timeout() {
  return Timestamp::at(emscripten_timeout).in();
}
void ConcurrentScheduler::emscripten_clear_main_timeout() {
  emscripten_timeout = 0;
}

void ConcurrentScheduler::finish() {
  CHECK(state_ == State::Run);
  if (!is_finished()) {
    on_finish();
  }
#if TD_PORT_WINDOWS
  SCOPE_EXIT {
    iocp_->clear();
  };
  detail::Iocp::Guard iocp_guard(iocp_.get());
#endif

  if (ExitGuard::is_exited()) {
#if !TD_THREAD_UNSUPPORTED && !TD_EVENTFD_UNSUPPORTED
    // prevent closing of schedulers from already killed by OS threads
    for (auto &thread : threads_) {
      thread.detach();
    }
#endif

#if TD_PORT_WINDOWS
    iocp_->interrupt_loop();
    iocp_thread_.detach();
#endif
    return;
  }

#if !TD_THREAD_UNSUPPORTED && !TD_EVENTFD_UNSUPPORTED
  for (auto &thread : threads_) {
    thread.join();
  }
  threads_.clear();
#endif

#if TD_PORT_WINDOWS
  iocp_->interrupt_loop();
  iocp_thread_.join();
#endif

  schedulers_.clear();
  for (auto &f : at_finish_) {
    f();
  }
  at_finish_.clear();

  state_ = State::Start;
}

void ConcurrentScheduler::on_finish() {
  is_finished_.store(true, std::memory_order_relaxed);
  for (auto &it : schedulers_) {
    it->wakeup();
  }
}

void ConcurrentScheduler::register_at_finish(std::function<void()> f) {
  std::lock_guard<std::mutex> lock(at_finish_mutex_);
  at_finish_.push_back(std::move(f));
}

}  // namespace td
