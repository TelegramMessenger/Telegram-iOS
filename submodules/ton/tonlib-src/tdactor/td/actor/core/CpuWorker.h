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

    Copyright 2017-2020 Telegram Systems LLP
*/
#pragma once

#include "td/actor/core/SchedulerMessage.h"

#include "td/utils/MpmcQueue.h"
#include "td/utils/MpmcWaiter.h"
#include "td/utils/Span.h"

namespace td {
namespace actor {
namespace core {
template <class T>
struct LocalQueue;
class CpuWorker {
 public:
  CpuWorker(MpmcQueue<SchedulerMessage::Raw *> &queue, MpmcWaiter &waiter, size_t id,
            MutableSpan<LocalQueue<SchedulerMessage::Raw *>> local_queues)
      : queue_(queue), waiter_(waiter), id_(id), local_queues_(local_queues) {
  }
  void run();

 private:
  MpmcQueue<SchedulerMessage::Raw *> &queue_;
  MpmcWaiter &waiter_;
  size_t id_;
  MutableSpan<LocalQueue<SchedulerMessage::Raw *>> local_queues_;
  size_t cnt_{0};

  bool try_pop(SchedulerMessage &message, size_t thread_id);

  bool try_pop_local(SchedulerMessage &message);
  bool try_pop_global(SchedulerMessage &message, size_t thread_id);
};
}  // namespace core
}  // namespace actor
}  // namespace td
