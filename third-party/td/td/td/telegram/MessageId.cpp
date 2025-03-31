//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/MessageId.h"

#include "td/utils/algorithm.h"
#include "td/utils/logging.h"
#include "td/utils/misc.h"

namespace td {

MessageId::MessageId(ScheduledServerMessageId server_message_id, int32 send_date, bool force) {
  if (send_date <= (1 << 30)) {
    LOG(ERROR) << "Scheduled message send date " << send_date << " is in the past";
    return;
  }
  if (!server_message_id.is_valid() && !force) {
    LOG(ERROR) << "Scheduled message ID " << server_message_id.get() << " is invalid";
    return;
  }
  id = (static_cast<int64>(send_date - (1 << 30)) << 21) | (static_cast<int64>(server_message_id.get()) << 3) |
       SCHEDULED_MASK;
}

MessageId MessageId::get_message_id(const telegram_api::Message *message_ptr, bool is_scheduled) {
  CHECK(message_ptr != nullptr);
  switch (message_ptr->get_id()) {
    case telegram_api::messageEmpty::ID: {
      auto message = static_cast<const telegram_api::messageEmpty *>(message_ptr);
      return is_scheduled ? MessageId() : MessageId(ServerMessageId(message->id_));
    }
    case telegram_api::message::ID: {
      auto message = static_cast<const telegram_api::message *>(message_ptr);
      return is_scheduled ? MessageId(ScheduledServerMessageId(message->id_), message->date_)
                          : MessageId(ServerMessageId(message->id_));
    }
    case telegram_api::messageService::ID: {
      auto message = static_cast<const telegram_api::messageService *>(message_ptr);
      return is_scheduled ? MessageId(ScheduledServerMessageId(message->id_), message->date_)
                          : MessageId(ServerMessageId(message->id_));
    }
    default:
      UNREACHABLE();
      return MessageId();
  }
}

MessageId MessageId::get_message_id(const tl_object_ptr<telegram_api::Message> &message_ptr, bool is_scheduled) {
  return get_message_id(message_ptr.get(), is_scheduled);
}

MessageId MessageId::get_max_message_id(const vector<telegram_api::object_ptr<telegram_api::Message>> &messages) {
  MessageId max_message_id;
  for (auto &message : messages) {
    auto message_id = get_message_id(message, false);
    if (message_id > max_message_id) {
      max_message_id = message_id;
    }
  }
  return max_message_id;
}

vector<MessageId> MessageId::get_message_ids(const vector<int64> &input_message_ids) {
  return transform(input_message_ids, [](int64 input_message_id) { return MessageId(input_message_id); });
}

vector<int32> MessageId::get_server_message_ids(const vector<MessageId> &message_ids) {
  return transform(message_ids, [](MessageId message_id) { return message_id.get_server_message_id().get(); });
}

vector<int32> MessageId::get_scheduled_server_message_ids(const vector<MessageId> &message_ids) {
  return transform(message_ids,
                   [](MessageId message_id) { return message_id.get_scheduled_server_message_id().get(); });
}

bool MessageId::is_valid() const {
  if (id <= 0 || id > max().get()) {
    return false;
  }
  if ((id & FULL_TYPE_MASK) == 0) {
    return true;
  }
  int32 type = (id & TYPE_MASK);
  return type == TYPE_YET_UNSENT || type == TYPE_LOCAL;
}

bool MessageId::is_valid_scheduled() const {
  if (id <= 0 || id > (static_cast<int64>(1) << 51)) {
    return false;
  }
  int32 type = (id & TYPE_MASK);
  return type == SCHEDULED_MASK || type == (SCHEDULED_MASK | TYPE_YET_UNSENT) || type == (SCHEDULED_MASK | TYPE_LOCAL);
}

bool MessageId::is_valid_sponsored() const {
  if (id <= max().get() || id > (static_cast<int64>(1) << 51)) {
    return false;
  }
  int32 type = (id & TYPE_MASK);
  return type == TYPE_LOCAL;
}

MessageType MessageId::get_type() const {
  if (id <= 0 || id > (static_cast<int64>(1) << 51)) {
    return MessageType::None;
  }

  if (is_scheduled()) {
    switch (id & TYPE_MASK) {
      case SCHEDULED_MASK | TYPE_YET_UNSENT:
        return MessageType::YetUnsent;
      case SCHEDULED_MASK | TYPE_LOCAL:
        return MessageType::Local;
      case SCHEDULED_MASK:
        return MessageType::Server;
      default:
        return MessageType::None;
    }
  }

  if ((id & FULL_TYPE_MASK) == 0) {
    return MessageType::Server;
  }
  switch (id & TYPE_MASK) {
    case TYPE_YET_UNSENT:
      return MessageType::YetUnsent;
    case TYPE_LOCAL:
      return MessageType::Local;
    default:
      return MessageType::None;
  }
}

ServerMessageId MessageId::get_server_message_id_force() const {
  CHECK(!is_scheduled());
  return ServerMessageId(narrow_cast<int32>(id >> SERVER_ID_SHIFT));
}

MessageId MessageId::get_next_message_id(MessageType type) const {
  if (is_scheduled()) {
    CHECK(is_valid_scheduled());
    auto current_type = get_type();
    if (static_cast<int32>(current_type) < static_cast<int32>(type)) {
      return MessageId(id - static_cast<int32>(current_type) + static_cast<int32>(type));
    }
    int64 base_id = (id & ~TYPE_MASK) + TYPE_MASK + 1 + SCHEDULED_MASK;
    switch (type) {
      case MessageType::Server:
        return MessageId(base_id);
      case MessageType::YetUnsent:
        return MessageId(base_id + TYPE_YET_UNSENT);
      case MessageType::Local:
        return MessageId(base_id + TYPE_LOCAL);
      case MessageType::None:
      default:
        UNREACHABLE();
        return MessageId();
    }
  }

  switch (type) {
    case MessageType::Server:
      if (is_server()) {
        return MessageId(ServerMessageId(get_server_message_id().get() + 1));
      }
      return get_next_server_message_id();
    case MessageType::YetUnsent:
      return MessageId(((id + TYPE_MASK + 1 - TYPE_YET_UNSENT) & ~TYPE_MASK) + TYPE_YET_UNSENT);
    case MessageType::Local:
      return MessageId(((id + TYPE_MASK + 1 - TYPE_LOCAL) & ~TYPE_MASK) + TYPE_LOCAL);
    case MessageType::None:
    default:
      UNREACHABLE();
      return MessageId();
  }
}

StringBuilder &operator<<(StringBuilder &string_builder, MessageId message_id) {
  if (message_id.is_scheduled()) {
    string_builder << "scheduled ";

    if (!message_id.is_valid_scheduled()) {
      return string_builder << "invalid message " << message_id.get();
    }
    if (message_id.is_scheduled_server()) {
      return string_builder << "server message " << message_id.get_scheduled_server_message_id_force().get();
    }
    if (message_id.is_local()) {
      return string_builder << "local message " << message_id.get_scheduled_server_message_id_force().get();
    }
    if (message_id.is_yet_unsent()) {
      return string_builder << "yet unsent message " << message_id.get_scheduled_server_message_id_force().get();
    }
    return string_builder << "bugged message " << message_id.get();
  }

  if (!message_id.is_valid()) {
    return string_builder << "invalid message " << message_id.get();
  }
  if (message_id.is_server()) {
    return string_builder << "server message " << message_id.get_server_message_id_force().get();
  }
  if (message_id.is_local()) {
    return string_builder << "local message " << message_id.get_server_message_id_force().get() << '.'
                          << (message_id.get() & MessageId::FULL_TYPE_MASK);
  }
  if (message_id.is_yet_unsent()) {
    return string_builder << "yet unsent message " << message_id.get_server_message_id_force().get() << '.'
                          << (message_id.get() & MessageId::FULL_TYPE_MASK);
  }
  return string_builder << "bugged message " << message_id.get();
}

}  // namespace td
