//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/MessageSelfDestructType.h"

namespace td {

bool MessageSelfDestructType::is_valid() const {
  return ttl_ > 0;
}

bool MessageSelfDestructType::is_empty() const {
  return ttl_ == 0;
}

bool MessageSelfDestructType::is_immediate() const {
  return ttl_ == 0x7FFFFFFF;
}

bool MessageSelfDestructType::is_secret_message_content(MessageContentType content_type) {
  if (ttl_ <= 0 || ttl_ > 60) {
    return is_immediate();
  }
  return can_be_secret_message_content(content_type);
}

void MessageSelfDestructType::ensure_at_least(int32 ttl) {
  if (is_immediate() || ttl_ >= ttl || ttl_ <= 0 || ttl <= 0) {
    return;
  }
  ttl_ = ttl;
}

Result<MessageSelfDestructType> MessageSelfDestructType::get_message_self_destruct_type(
    td_api::object_ptr<td_api::MessageSelfDestructType> &&self_destruct_type) {
  if (self_destruct_type == nullptr) {
    return MessageSelfDestructType();
  }
  switch (self_destruct_type->get_id()) {
    case td_api::messageSelfDestructTypeTimer::ID: {
      auto ttl =
          static_cast<const td_api::messageSelfDestructTypeTimer *>(self_destruct_type.get())->self_destruct_time_;

      static constexpr int32 MAX_PRIVATE_MESSAGE_TTL = 60;  // server side limit
      if (ttl <= 0 || ttl > MAX_PRIVATE_MESSAGE_TTL) {
        return Status::Error(400, "Invalid message content self-destruct time specified");
      }
      return MessageSelfDestructType(ttl, true);
    }
    case td_api::messageSelfDestructTypeImmediately::ID:
      return MessageSelfDestructType(0x7FFFFFFF, true);
    default:
      UNREACHABLE();
      return MessageSelfDestructType();
  }
}

td_api::object_ptr<td_api::MessageSelfDestructType> MessageSelfDestructType::get_message_self_destruct_type_object()
    const {
  if (is_immediate()) {
    return td_api::make_object<td_api::messageSelfDestructTypeImmediately>();
  }
  if (!is_empty()) {
    return td_api::make_object<td_api::messageSelfDestructTypeTimer>(ttl_);
  }
  return nullptr;
}

int32 MessageSelfDestructType::get_input_ttl() const {
  return ttl_;
}

bool operator==(const MessageSelfDestructType &lhs, const MessageSelfDestructType &rhs) {
  return lhs.ttl_ == rhs.ttl_;
}

StringBuilder &operator<<(StringBuilder &string_builder, const MessageSelfDestructType &message_ttl) {
  if (message_ttl.is_empty()) {
    return string_builder << "non-self-destruct";
  }
  if (message_ttl.is_immediate()) {
    return string_builder << "self-destruct immediately";
  }
  return string_builder << "self-destruct at " << message_ttl.get_input_ttl();
}

}  // namespace td
