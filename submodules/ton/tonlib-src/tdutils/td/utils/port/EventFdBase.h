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

#include "td/utils/common.h"
#include "td/utils/port/detail/PollableFd.h"
#include "td/utils/Status.h"

namespace td {
class EventFdBase {
 public:
  EventFdBase() = default;
  EventFdBase(const EventFdBase &) = delete;
  EventFdBase &operator=(const EventFdBase &) = delete;
  EventFdBase(EventFdBase &&) = default;
  EventFdBase &operator=(EventFdBase &&) = default;
  virtual ~EventFdBase() = default;

  virtual void init() = 0;
  virtual bool empty() = 0;
  virtual void close() = 0;
  virtual PollableFdInfo &get_poll_info() = 0;
  virtual Status get_pending_error() TD_WARN_UNUSED_RESULT = 0;
  virtual void release() = 0;
  virtual void acquire() = 0;
  virtual void wait(int timeout_ms) = 0;
};
}  // namespace td
