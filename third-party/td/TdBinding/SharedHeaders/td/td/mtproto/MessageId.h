//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/utils/common.h"
#include "td/utils/format.h"
#include "td/utils/HashTableUtils.h"
#include "td/utils/StringBuilder.h"

#include <type_traits>

namespace td {
namespace mtproto {

class MessageId {
  uint64 message_id_ = 0;

 public:
  MessageId() = default;

  explicit constexpr MessageId(uint64 message_id) : message_id_(message_id) {
  }
  template <class T, typename = std::enable_if_t<std::is_convertible<T, int64>::value>>
  MessageId(T message_id) = delete;

  uint64 get() const {
    return message_id_;
  }

  bool operator==(const MessageId &other) const {
    return message_id_ == other.message_id_;
  }

  bool operator!=(const MessageId &other) const {
    return message_id_ != other.message_id_;
  }

  friend bool operator<(const MessageId &lhs, const MessageId &rhs) {
    return lhs.get() < rhs.get();
  }

  friend bool operator>(const MessageId &lhs, const MessageId &rhs) {
    return lhs.get() > rhs.get();
  }

  friend bool operator<=(const MessageId &lhs, const MessageId &rhs) {
    return lhs.get() <= rhs.get();
  }

  friend bool operator>=(const MessageId &lhs, const MessageId &rhs) {
    return lhs.get() >= rhs.get();
  }
};

struct MessageIdHash {
  uint32 operator()(MessageId message_id) const {
    return Hash<uint64>()(message_id.get());
  }
};

inline StringBuilder &operator<<(StringBuilder &string_builder, MessageId message_id) {
  return string_builder << "message " << format::as_hex(message_id.get());
}

}  // namespace mtproto
}  // namespace td
