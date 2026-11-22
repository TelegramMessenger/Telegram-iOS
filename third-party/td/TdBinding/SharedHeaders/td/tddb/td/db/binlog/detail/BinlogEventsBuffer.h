//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/db/binlog/BinlogEvent.h"

#include "td/utils/common.h"

namespace td {
namespace detail {

class BinlogEventsBuffer {
 public:
  void add_event(BinlogEvent &&event);

  bool need_flush() const;

  template <class CallbackT>
  void flush(CallbackT &&callback) {
    for (size_t i = 0; i < ids_.size(); i++) {
      auto &event = events_[i];
      if (i + 1 != ids_.size() && (event.flags_ & BinlogEvent::Flags::Partial) == 0) {
        callback(BinlogEvent(BinlogEvent::create_raw(event.id_, event.type_, event.flags_ | BinlogEvent::Flags::Partial,
                                                     create_storer(event.get_data())),
                             BinlogDebugInfo{__FILE__, __LINE__}));
      } else {
        callback(std::move(event));
      }
    }
    clear();
  }
  size_t size() const {
    return size_;
  }

 private:
  vector<uint64> ids_;
  vector<BinlogEvent> events_;
  size_t total_events_{0};
  size_t size_{0};

  void do_event(BinlogEvent &&event);
  void clear();
};

}  // namespace detail
}  // namespace td
