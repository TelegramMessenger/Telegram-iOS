//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/db/binlog/BinlogEvent.h"

#include "td/utils/common.h"
#include "td/utils/logging.h"
#include "td/utils/Status.h"

namespace td {
namespace detail {

class BinlogEventsProcessor {
 public:
  Status add_event(BinlogEvent &&event) TD_WARN_UNUSED_RESULT {
    return do_event(std::move(event));
  }

  template <class CallbackT>
  void for_each(CallbackT &&callback) {
    for (size_t i = 0; i < event_ids_.size(); i++) {
      LOG_CHECK(i == 0 || event_ids_[i - 1] < event_ids_[i])
          << event_ids_[i - 1] << " " << events_[i - 1].public_to_string() << " " << event_ids_[i] << " "
          << events_[i].public_to_string();
      if ((event_ids_[i] & 1) == 0) {
        callback(events_[i]);
      }
    }
  }

  uint64 last_event_id() const {
    return last_event_id_;
  }
  int64 offset() const {
    return offset_;
  }
  int64 total_raw_events_size() const {
    return total_raw_events_size_;
  }

 private:
  // holds (event_id * 2 + was_deleted)
  std::vector<uint64> event_ids_;
  std::vector<BinlogEvent> events_;
  size_t total_events_{0};
  size_t empty_events_{0};
  uint64 last_event_id_{0};
  int64 offset_{0};
  int64 total_raw_events_size_{0};

  Status do_event(BinlogEvent &&event);
  void compactify();
};

}  // namespace detail
}  // namespace td
