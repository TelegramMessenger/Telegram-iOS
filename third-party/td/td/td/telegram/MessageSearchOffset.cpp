//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/MessageSearchOffset.h"

#include "td/telegram/DialogManager.h"
#include "td/telegram/MessagesManager.h"
#include "td/telegram/ServerMessageId.h"

#include "td/utils/misc.h"
#include "td/utils/SliceBuilder.h"
#include "td/utils/StringBuilder.h"

#include <limits>

namespace td {

void MessageSearchOffset::update_from_message(const telegram_api::object_ptr<telegram_api::Message> &message) {
  auto message_date = MessagesManager::get_message_date(message);
  auto message_id = MessageId::get_message_id(message, false);
  auto dialog_id = DialogId::get_message_dialog_id(message);
  if (message_date > 0 && message_id.is_valid() && dialog_id.is_valid()) {
    date_ = message_date;
    message_id_ = message_id;
    dialog_id_ = dialog_id;
  }
}

string MessageSearchOffset::to_string() const {
  return PSTRING() << date_ << ',' << dialog_id_.get() << ',' << message_id_.get_server_message_id().get();
}

Result<MessageSearchOffset> MessageSearchOffset::from_string(const string &offset) {
  MessageSearchOffset result;
  result.date_ = std::numeric_limits<int32>::max();
  bool is_offset_valid = [&] {
    if (offset.empty()) {
      return true;
    }

    auto parts = full_split(offset, ',');
    if (parts.size() != 3) {
      return false;
    }
    auto r_offset_date = to_integer_safe<int32>(parts[0]);
    auto r_offset_dialog_id = to_integer_safe<int64>(parts[1]);
    auto r_offset_message_id = to_integer_safe<int32>(parts[2]);
    if (r_offset_date.is_error() || r_offset_message_id.is_error() || r_offset_dialog_id.is_error()) {
      return false;
    }
    result.date_ = r_offset_date.ok();
    result.message_id_ = MessageId(ServerMessageId(r_offset_message_id.ok()));
    result.dialog_id_ = DialogId(r_offset_dialog_id.ok());
    if (result.date_ <= 0 || !result.message_id_.is_valid() || !result.dialog_id_.is_valid() ||
        DialogManager::get_input_peer_force(result.dialog_id_)->get_id() == telegram_api::inputPeerEmpty::ID) {
      return false;
    }
    return true;
  }();
  if (!is_offset_valid) {
    return Status::Error(400, "Invalid offset specified");
  }
  return std::move(result);
}

}  // namespace td
