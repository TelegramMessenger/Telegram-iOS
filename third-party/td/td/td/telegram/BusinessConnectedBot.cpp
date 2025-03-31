//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/BusinessConnectedBot.h"

#include "td/telegram/Td.h"
#include "td/telegram/UserManager.h"

namespace td {

BusinessConnectedBot::BusinessConnectedBot(telegram_api::object_ptr<telegram_api::connectedBot> connected_bot) {
  CHECK(connected_bot != nullptr);
  user_id_ = UserId(connected_bot->bot_id_);
  recipients_ = BusinessRecipients(std::move(connected_bot->recipients_));
  can_reply_ = connected_bot->can_reply_;
}

BusinessConnectedBot::BusinessConnectedBot(td_api::object_ptr<td_api::businessConnectedBot> connected_bot) {
  if (connected_bot == nullptr) {
    return;
  }
  user_id_ = UserId(connected_bot->bot_user_id_);
  recipients_ = BusinessRecipients(std::move(connected_bot->recipients_), true);
  can_reply_ = connected_bot->can_reply_;
}

td_api::object_ptr<td_api::businessConnectedBot> BusinessConnectedBot::get_business_connected_bot_object(Td *td) const {
  CHECK(is_valid());
  return td_api::make_object<td_api::businessConnectedBot>(
      td->user_manager_->get_user_id_object(user_id_, "businessConnectedBot"),
      recipients_.get_business_recipients_object(td), can_reply_);
}

bool operator==(const BusinessConnectedBot &lhs, const BusinessConnectedBot &rhs) {
  return lhs.user_id_ == rhs.user_id_ && lhs.recipients_ == rhs.recipients_ && lhs.can_reply_ == rhs.can_reply_;
}

StringBuilder &operator<<(StringBuilder &string_builder, const BusinessConnectedBot &connected_bot) {
  return string_builder << "connected bot " << connected_bot.user_id_ << ' ' << connected_bot.recipients_ << ' '
                        << (connected_bot.can_reply_ ? " that can reply" : " read-only");
}

}  // namespace td
