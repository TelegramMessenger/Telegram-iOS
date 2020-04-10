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
#include "td/actor/core/IoWorker.h"

#include "td/actor/core/ActorExecutor.h"

namespace td {
namespace actor {
namespace core {
void IoWorker::start_up() {
#if TD_PORT_POSIX
  auto &poll = SchedulerContext::get()->get_poll();
  poll.subscribe(queue_.reader_get_event_fd().get_poll_info().extract_pollable_fd(nullptr), PollFlags::Read());
#endif
}
void IoWorker::tear_down() {
#if TD_PORT_POSIX
  auto &poll = SchedulerContext::get()->get_poll();
  poll.unsubscribe(queue_.reader_get_event_fd().get_poll_info().get_pollable_fd_ref());
#endif
}

bool IoWorker::run_once(double timeout) {
  auto &dispatcher = *SchedulerContext::get();
#if TD_PORT_POSIX
  auto &poll = SchedulerContext::get()->get_poll();
#endif
  auto &heap = SchedulerContext::get()->get_heap();

  auto now = Time::now();  // update Time::now_cached()
  while (!heap.empty() && heap.top_key() <= now) {
    auto *heap_node = heap.pop();
    auto *actor_info = ActorInfo::from_heap_node(heap_node);

    auto id = actor_info->unpin();
    ActorExecutor executor(*actor_info, dispatcher, ActorExecutor::Options().with_has_poll(true));
    if (executor.can_send_immediate()) {
      executor.send_immediate(ActorSignals::one(ActorSignals::Alarm));
    } else {
      executor.send(ActorSignals::one(ActorSignals::Alarm));
    }
  }

  const int size = queue_.reader_wait_nonblock();
  for (int i = 0; i < size; i++) {
    auto message = queue_.reader_get_unsafe();
    if (!message) {
      return false;
    }
    if (message->state().get_flags_unsafe().is_shared()) {
      // should check actors timeout
      dispatcher.set_alarm_timestamp(message);
      continue;
    }
    ActorExecutor executor(*message, dispatcher, ActorExecutor::Options().with_from_queue().with_has_poll(true));
  }
  queue_.reader_flush();

  bool can_sleep = size == 0 && timeout != 0;
  int32 timeout_ms = 0;
  if (can_sleep) {
    auto wakeup_timestamp = Timestamp::in(timeout);
    if (!heap.empty()) {
      wakeup_timestamp.relax(Timestamp::at(heap.top_key()));
    }
    timeout_ms = static_cast<int>(wakeup_timestamp.in() * 1000) + 1;
    if (timeout_ms < 0) {
      timeout_ms = 0;
    }
    //const int thirty_seconds = 30 * 1000;
    //if (timeout_ms > thirty_seconds) {
    //timeout_ms = thirty_seconds;
    //}
  }
#if TD_PORT_POSIX
  poll.run(timeout_ms);
#elif TD_PORT_WINDOWS
  queue_.reader_get_event_fd().wait(timeout_ms);
#endif
  return true;
}
}  // namespace core
}  // namespace actor
}  // namespace td
