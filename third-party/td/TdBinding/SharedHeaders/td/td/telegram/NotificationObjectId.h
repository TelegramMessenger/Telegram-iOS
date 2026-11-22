//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/MessageId.h"

#include "td/utils/common.h"
#include "td/utils/HashTableUtils.h"
#include "td/utils/StringBuilder.h"

namespace td {

class NotificationObjectId {
  int64 id = 0;

 public:
  NotificationObjectId() = default;

  NotificationObjectId(MessageId message_id) : id(message_id.get()) {
  }

  static NotificationObjectId max() {
    return NotificationObjectId(MessageId::max());
  }

  int64 get() const {
    return id;
  }

  bool is_valid() const {
    return id > 0;
  }

  bool operator==(const NotificationObjectId &other) const {
    return id == other.id;
  }

  bool operator!=(const NotificationObjectId &other) const {
    return id != other.id;
  }

  friend bool operator<(const NotificationObjectId &lhs, const NotificationObjectId &rhs) {
    return lhs.id < rhs.id;
  }

  friend bool operator>(const NotificationObjectId &lhs, const NotificationObjectId &rhs) {
    return lhs.id > rhs.id;
  }

  friend bool operator<=(const NotificationObjectId &lhs, const NotificationObjectId &rhs) {
    return lhs.id <= rhs.id;
  }

  friend bool operator>=(const NotificationObjectId &lhs, const NotificationObjectId &rhs) {
    return lhs.id >= rhs.id;
  }

  template <class StorerT>
  void store(StorerT &storer) const {
    storer.store_long(id);
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    id = parser.fetch_long();
  }
};

struct NotificationObjectIdHash {
  uint32 operator()(NotificationObjectId notification_object_id) const {
    return Hash<int64>()(notification_object_id.get());
  }
};

inline StringBuilder &operator<<(StringBuilder &string_builder, NotificationObjectId notification_object_id) {
  return string_builder << "notification object " << notification_object_id.get();
}

}  // namespace td
