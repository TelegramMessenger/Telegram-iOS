//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/db/binlog/detail/BinlogEventsProcessor.h"

#include "td/utils/SliceBuilder.h"
#include "td/utils/Status.h"

#include <algorithm>

namespace td {
namespace detail {

Status BinlogEventsProcessor::do_event(BinlogEvent &&event) {
  offset_ = event.offset_;
  auto fixed_event_id = event.id_ * 2;
  if ((event.flags_ & BinlogEvent::Flags::Rewrite) && !event_ids_.empty() && event_ids_.back() >= fixed_event_id) {
    auto it = std::lower_bound(event_ids_.begin(), event_ids_.end(), fixed_event_id);
    if (it == event_ids_.end() || *it != fixed_event_id) {
      return Status::Error(PSLICE() << "Ignore rewrite log event " << event.public_to_string());
    }
    auto pos = it - event_ids_.begin();
    total_raw_events_size_ -= static_cast<int64>(events_[pos].raw_event_.size());
    if (event.type_ == BinlogEvent::ServiceTypes::Empty) {
      *it += 1;
      empty_events_++;
      events_[pos] = {};
    } else {
      event.flags_ &= ~BinlogEvent::Flags::Rewrite;
      total_raw_events_size_ += static_cast<int64>(event.raw_event_.size());
      events_[pos] = std::move(event);
    }
  } else if (event.type_ < 0) {
    // just skip service events
  } else {
    if (!(event_ids_.empty() || event_ids_.back() < fixed_event_id)) {
      return Status::Error(PSLICE() << offset_ << ' ' << event_ids_.size() << ' ' << event_ids_.back() << ' '
                                    << fixed_event_id << ' ' << event.public_to_string() << ' ' << total_events_ << ' '
                                    << total_raw_events_size_);
    }
    last_event_id_ = event.id_;
    total_raw_events_size_ += static_cast<int64>(event.raw_event_.size());
    total_events_++;
    event_ids_.push_back(fixed_event_id);
    events_.emplace_back(std::move(event));
  }

  if (total_events_ > 10 && empty_events_ * 4 > total_events_ * 3) {
    compactify();
  }
  return Status::OK();
}

void BinlogEventsProcessor::compactify() {
  CHECK(event_ids_.size() == events_.size());
  auto event_ids_from = event_ids_.begin();
  auto event_ids_to = event_ids_from;
  auto events_from = events_.begin();
  auto events_to = events_from;
  for (; event_ids_from != event_ids_.end(); event_ids_from++, events_from++) {
    if ((*event_ids_from & 1) == 0) {
      *event_ids_to++ = *event_ids_from;
      if (events_to != events_from) {
        *events_to = std::move(*events_from);
      }
      events_to++;
    }
  }
  event_ids_.erase(event_ids_to, event_ids_.end());
  events_.erase(events_to, events_.end());
  total_events_ = event_ids_.size();
  empty_events_ = 0;
  CHECK(event_ids_.size() == events_.size());
}

}  // namespace detail
}  // namespace td
