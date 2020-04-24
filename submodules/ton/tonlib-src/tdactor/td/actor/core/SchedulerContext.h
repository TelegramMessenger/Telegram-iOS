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
#include "td/actor/core/Context.h"
#include "td/actor/core/SchedulerId.h"
#include "td/actor/core/ActorInfo.h"
#include "td/actor/core/ActorInfoCreator.h"

#include "td/utils/port/Poll.h"
#include "td/utils/Heap.h"

namespace td {
namespace actor {
namespace core {
class SchedulerDispatcher {
 public:
  virtual ~SchedulerDispatcher() = default;

  virtual SchedulerId get_scheduler_id() const = 0;
  virtual void add_to_queue(ActorInfoPtr actor_info_ptr, SchedulerId scheduler_id, bool need_poll) = 0;
  virtual void set_alarm_timestamp(const ActorInfoPtr &actor_info_ptr) = 0;
};

struct Debug;
class SchedulerContext : public Context<SchedulerContext>, public SchedulerDispatcher {
 public:
  virtual ~SchedulerContext() = default;

  // ActorCreator Interface
  virtual ActorInfoCreator &get_actor_info_creator() = 0;

  // Poll interface
  virtual bool has_poll() = 0;
  virtual Poll &get_poll() = 0;

  // Timeout interface
  virtual bool has_heap() = 0;
  virtual KHeap<double> &get_heap() = 0;

  // Stop all schedulers
  virtual bool is_stop_requested() = 0;
  virtual void stop() = 0;

  // Debug
  virtual Debug &get_debug() = 0;
};
}  // namespace core
}  // namespace actor
}  // namespace td
