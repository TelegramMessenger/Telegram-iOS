//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/ScheduledServerMessageId.h"
#include "td/telegram/ServerMessageId.h"
#include "td/telegram/telegram_api.h"

#include "td/utils/common.h"
#include "td/utils/HashTableUtils.h"
#include "td/utils/StringBuilder.h"

#include <limits>
#include <type_traits>

namespace td {

enum class MessageType : int32 { None, Server, YetUnsent, Local };

class MessageId {
  int64 id = 0;

  static constexpr int32 SERVER_ID_SHIFT = 20;
  static constexpr int32 SHORT_TYPE_MASK = (1 << 2) - 1;
  static constexpr int32 TYPE_MASK = (1 << 3) - 1;
  static constexpr int32 FULL_TYPE_MASK = (1 << SERVER_ID_SHIFT) - 1;
  static constexpr int32 SCHEDULED_MASK = 4;
  static constexpr int32 TYPE_YET_UNSENT = 1;
  static constexpr int32 TYPE_LOCAL = 2;

  friend StringBuilder &operator<<(StringBuilder &string_builder, MessageId message_id);

  // ordinary message ID layout
  // |-------31--------|---17---|1|--2-|
  // |server_message_id|local_id|0|type|

  // scheduled message ID layout
  // |-------30-------|----18---|1|--2-|
  // |send_date-2**30 |server_id|1|type|

  // sponsored message ID layout
  // |-------31--------|---17---|1|-2|
  // |11111111111111111|local_id|0|10|

  ServerMessageId get_server_message_id_force() const;

  ScheduledServerMessageId get_scheduled_server_message_id_force() const {
    CHECK(is_scheduled());
    return ScheduledServerMessageId(static_cast<int32>((id >> 3) & ((1 << 18) - 1)));
  }

 public:
  MessageId() = default;

  explicit MessageId(ServerMessageId server_message_id)
      : id(static_cast<int64>(server_message_id.get()) << SERVER_ID_SHIFT) {
  }

  MessageId(ScheduledServerMessageId server_message_id, int32 send_date, bool force = false);

  explicit constexpr MessageId(int64 message_id) : id(message_id) {
  }
  template <class T, typename = std::enable_if_t<std::is_convertible<T, int64>::value>>
  MessageId(T message_id) = delete;

  static constexpr MessageId min() {
    return MessageId(static_cast<int64>(MessageId::TYPE_YET_UNSENT));
  }
  static constexpr MessageId max() {
    return MessageId(static_cast<int64>(std::numeric_limits<int32>::max()) << SERVER_ID_SHIFT);
  }

  static MessageId get_message_id(const telegram_api::Message *message_ptr, bool is_scheduled);

  static MessageId get_message_id(const tl_object_ptr<telegram_api::Message> &message_ptr, bool is_scheduled);

  static MessageId get_max_message_id(const vector<telegram_api::object_ptr<telegram_api::Message>> &messages);

  static vector<MessageId> get_message_ids(const vector<int64> &input_message_ids);

  static vector<int32> get_server_message_ids(const vector<MessageId> &message_ids);

  static vector<int32> get_scheduled_server_message_ids(const vector<MessageId> &message_ids);

  bool is_valid() const;

  bool is_valid_scheduled() const;

  bool is_valid_sponsored() const;

  int64 get() const {
    return id;
  }

  MessageType get_type() const;

  bool is_scheduled() const {
    return (id & SCHEDULED_MASK) != 0;
  }

  bool is_yet_unsent() const {
    CHECK(is_valid() || is_scheduled());
    return (id & SHORT_TYPE_MASK) == TYPE_YET_UNSENT;
  }

  bool is_local() const {
    CHECK(is_valid() || is_scheduled());
    return (id & SHORT_TYPE_MASK) == TYPE_LOCAL;
  }

  bool is_server() const {
    CHECK(is_valid());
    return (id & FULL_TYPE_MASK) == 0;
  }

  bool is_scheduled_server() const {
    CHECK(is_valid_scheduled());
    return (id & SHORT_TYPE_MASK) == 0;
  }

  bool is_any_server() const {
    return is_scheduled() ? is_scheduled_server() : is_server();
  }

  ServerMessageId get_server_message_id() const {
    CHECK(id == 0 || is_server());
    return get_server_message_id_force();
  }

  // returns greatest server message identifier not bigger than this message identifier
  MessageId get_prev_server_message_id() const {
    CHECK(!is_scheduled());
    return MessageId(id & ~FULL_TYPE_MASK);
  }

  // returns smallest server message identifier not less than this message identifier
  MessageId get_next_server_message_id() const {
    CHECK(!is_scheduled());
    return MessageId((id + FULL_TYPE_MASK) & ~FULL_TYPE_MASK);
  }

  MessageId get_next_message_id(MessageType type) const;

  ScheduledServerMessageId get_scheduled_server_message_id() const {
    CHECK(is_scheduled_server());
    return get_scheduled_server_message_id_force();
  }

  int32 get_scheduled_message_date() const {
    CHECK(is_valid_scheduled());
    return static_cast<int32>(id >> 21) + (1 << 30);
  }

  bool operator==(const MessageId &other) const {
    return id == other.id;
  }

  bool operator!=(const MessageId &other) const {
    return id != other.id;
  }

  friend bool operator<(const MessageId &lhs, const MessageId &rhs) {
    CHECK(lhs.is_scheduled() == rhs.is_scheduled());
    return lhs.id < rhs.id;
  }

  friend bool operator>(const MessageId &lhs, const MessageId &rhs) {
    CHECK(lhs.is_scheduled() == rhs.is_scheduled());
    return lhs.id > rhs.id;
  }

  friend bool operator<=(const MessageId &lhs, const MessageId &rhs) {
    CHECK(lhs.is_scheduled() == rhs.is_scheduled());
    return lhs.id <= rhs.id;
  }

  friend bool operator>=(const MessageId &lhs, const MessageId &rhs) {
    CHECK(lhs.is_scheduled() == rhs.is_scheduled());
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

struct MessageIdHash {
  uint32 operator()(MessageId message_id) const {
    return Hash<int64>()(message_id.get());
  }
};

}  // namespace td
