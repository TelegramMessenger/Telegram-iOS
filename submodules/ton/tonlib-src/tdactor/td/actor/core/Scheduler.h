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

#include "td/actor/core/ActorExecuteContext.h"
#include "td/actor/core/ActorExecutor.h"
#include "td/actor/core/Actor.h"
#include "td/actor/core/ActorInfo.h"
#include "td/actor/core/ActorInfoCreator.h"
#include "td/actor/core/ActorLocker.h"
#include "td/actor/core/ActorMailbox.h"
#include "td/actor/core/ActorMessage.h"
#include "td/actor/core/Context.h"
#include "td/actor/core/SchedulerContext.h"
#include "td/actor/core/SchedulerId.h"
#include "td/actor/core/SchedulerMessage.h"

#include "td/utils/Closure.h"
#include "td/utils/common.h"
#include "td/utils/format.h"
#include "td/utils/Heap.h"
#include "td/utils/List.h"
#include "td/utils/logging.h"
#include "td/utils/MpmcQueue.h"
#include "td/utils/MpmcWaiter.h"
#include "td/utils/MpscLinkQueue.h"
#include "td/utils/MpscPollableQueue.h"
#include "td/utils/port/Poll.h"
#include "td/utils/port/detail/Iocp.h"
#include "td/utils/port/thread.h"
#include "td/utils/port/thread_local.h"
#include "td/utils/ScopeGuard.h"
#include "td/utils/Slice.h"
#include "td/utils/Time.h"
#include "td/utils/type_traits.h"

#include <atomic>
#include <condition_variable>
#include <limits>
#include <memory>
#include <mutex>
#include <type_traits>
#include <utility>

namespace td {
namespace actor {
namespace core {
class IoWorker;

struct WorkerInfo {
  enum class Type { Io, Cpu } type{Type::Io};
  WorkerInfo() = default;
  explicit WorkerInfo(Type type, bool allow_shared) : type(type), actor_info_creator(allow_shared) {
  }
  ActorInfoCreator actor_info_creator;
};

struct SchedulerInfo {
  SchedulerId id;
  // will be read by all workers is any thread
  std::unique_ptr<MpmcQueue<SchedulerMessage>> cpu_queue;
  std::unique_ptr<MpmcWaiter> cpu_queue_waiter;
  // only scheduler itself may read from io_queue_
  std::unique_ptr<MpscPollableQueue<SchedulerMessage>> io_queue;
  size_t cpu_threads_count{0};

  std::unique_ptr<WorkerInfo> io_worker;
  std::vector<std::unique_ptr<WorkerInfo>> cpu_workers;
};

struct SchedulerGroupInfo {
  explicit SchedulerGroupInfo(size_t n) : schedulers(n) {
  }
  std::atomic<bool> is_stop_requested{false};

  int active_scheduler_count{0};
  std::mutex active_scheduler_count_mutex;
  std::condition_variable active_scheduler_count_condition_variable;

#if TD_PORT_WINDOWS
  td::detail::Iocp iocp;
  td::thread iocp_thread;
#endif
  std::vector<SchedulerInfo> schedulers;
};

class Scheduler {
 public:
  static constexpr int32 max_thread_count() {
    return 256;
  }

  static int32 get_thread_id() {
    auto thread_id = ::td::get_thread_id();
    CHECK(thread_id < max_thread_count());
    return thread_id;
  }

  Scheduler(std::shared_ptr<SchedulerGroupInfo> scheduler_group_info, SchedulerId id, size_t cpu_threads_count);

  Scheduler(const Scheduler &) = delete;
  Scheduler &operator=(const Scheduler &) = delete;
  Scheduler(Scheduler &&other) = delete;
  Scheduler &operator=(Scheduler &&other) = delete;
  ~Scheduler();

  void start();

  template <class F>
  void run_in_context(F &&f) {
    run_in_context_impl(*info_->io_worker, std::forward<F>(f));
  }

  template <class F>
  void run_in_context_external(F &&f) {
    WorkerInfo info;
    info.type = WorkerInfo::Type::Cpu;
    run_in_context_impl(*info_->io_worker, std::forward<F>(f));
  }

  bool run(double timeout);

  // Just syntactic sugar
  void stop() {
    run_in_context([] { SchedulerContext::get()->stop(); });
  }

  SchedulerId get_scheduler_id() const {
    return info_->id;
  }

 private:
  std::shared_ptr<SchedulerGroupInfo> scheduler_group_info_;
  SchedulerInfo *info_;
  std::vector<td::thread> cpu_threads_;
  bool is_stopped_{false};
  Poll poll_;
  KHeap<double> heap_;
  std::unique_ptr<IoWorker> io_worker_;

  class ContextImpl : public SchedulerContext {
   public:
    ContextImpl(ActorInfoCreator *creator, SchedulerId scheduler_id, SchedulerGroupInfo *scheduler_group, Poll *poll,
                KHeap<double> *heap);

    SchedulerId get_scheduler_id() const override;
    void add_to_queue(ActorInfoPtr actor_info_ptr, SchedulerId scheduler_id, bool need_poll) override;
    ActorInfoCreator &get_actor_info_creator() override;

    bool has_poll() override;
    Poll &get_poll() override;

    bool has_heap() override;
    KHeap<double> &get_heap() override;

    void set_alarm_timestamp(const ActorInfoPtr &actor_info_ptr) override;

    bool is_stop_requested() override;
    void stop() override;

   private:
    SchedulerGroupInfo *scheduler_group() const {
      return scheduler_group_;
    }

    ActorInfoCreator *creator_;
    SchedulerId scheduler_id_;
    SchedulerGroupInfo *scheduler_group_;
    Poll *poll_;

    KHeap<double> *heap_;
  };

  template <class F>
  void run_in_context_impl(WorkerInfo &worker_info, F &&f) {
#if TD_PORT_WINDOWS
    td::detail::Iocp::Guard iocp_guard(&scheduler_group_info_->iocp);
#endif
    bool is_io_worker = worker_info.type == WorkerInfo::Type::Io;
    ContextImpl context(&worker_info.actor_info_creator, info_->id, scheduler_group_info_.get(),
                        is_io_worker ? &poll_ : nullptr, is_io_worker ? &heap_ : nullptr);
    SchedulerContext::Guard guard(&context);
    f();
  }

  void do_stop();

 public:
  static void close_scheduler_group(SchedulerGroupInfo &group_info);
};

// Actor messages
class ActorMessageHangup : public core::ActorMessageImpl {
 public:
  void run() override {
    ActorExecuteContext::get()->actor().hangup();
  }
};
class ActorMessageHangupShared : public core::ActorMessageImpl {
 public:
  void run() override {
    ActorExecuteContext::get()->actor().hangup_shared();
  }
};
}  // namespace core
}  // namespace actor
}  // namespace td
