//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/db/binlog/detail/BinlogEventsBuffer.h"

#include <algorithm>

namespace td {
namespace detail {

void BinlogEventsBuffer::add_event(BinlogEvent &&event) {
  total_events_++;
  if ((event.flags_ & BinlogEvent::Flags::Partial) == 0) {
    auto it = std::find(ids_.begin(), ids_.end(), event.id_);
    if (it != ids_.end()) {
      auto &to_event = events_[it - ids_.begin()];
      size_ -= to_event.size_;
      to_event = std::move(event);
      size_ += to_event.size_;
      return;
    }
  }
  ids_.push_back(event.id_);
  size_ += event.size_;
  events_.push_back(std::move(event));
}

bool BinlogEventsBuffer::need_flush() const {
  return total_events_ > 5000 || ids_.size() > 100;
}

void BinlogEventsBuffer::clear() {
  ids_.clear();
  events_.clear();
  total_events_ = 0;
  size_ = 0;
}

}  // namespace detail
}  // namespace td
