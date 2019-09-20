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
#include "td/actor/core/CpuWorker.h"

#include "td/actor/core/ActorExecutor.h"
#include "td/actor/core/SchedulerContext.h"

namespace td {
namespace actor {
namespace core {
void CpuWorker::run() {
  auto thread_id = get_thread_id();
  auto &dispatcher = *SchedulerContext::get();

  int yields = 0;
  while (true) {
    SchedulerMessage message;
    if (queue_.try_pop(message, thread_id)) {
      if (!message) {
        return;
      }
      ActorExecutor executor(*message, dispatcher, ActorExecutor::Options().with_from_queue());
      yields = waiter_.stop_wait(yields, thread_id);
    } else {
      yields = waiter_.wait(yields, thread_id);
    }
  }
}
}  // namespace core
}  // namespace actor
}  // namespace td
