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

#include "td/actor/core/SchedulerContext.h"
#include "td/actor/core/SchedulerMessage.h"
#include "td/utils/MpscPollableQueue.h"

namespace td {
namespace actor {
namespace core {
class IoWorker {
 public:
  explicit IoWorker(MpscPollableQueue<SchedulerMessage> &queue) : queue_(queue) {
  }

  void start_up();
  void tear_down();

  bool run_once(double timeout);

 private:
  MpscPollableQueue<SchedulerMessage> &queue_;
};
}  // namespace core
}  // namespace actor
}  // namespace td
