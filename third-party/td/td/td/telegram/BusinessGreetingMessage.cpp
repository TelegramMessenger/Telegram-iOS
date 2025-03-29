//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/BusinessGreetingMessage.h"

#include "td/telegram/Dependencies.h"

#include "td/utils/misc.h"

namespace td {

BusinessGreetingMessage::BusinessGreetingMessage(
    telegram_api::object_ptr<telegram_api::businessGreetingMessage> greeting_message) {
  if (greeting_message == nullptr) {
    return;
  }
  shortcut_id_ = QuickReplyShortcutId(greeting_message->shortcut_id_);
  recipients_ = BusinessRecipients(std::move(greeting_message->recipients_));
  inactivity_days_ = clamp(greeting_message->no_activity_days_ / 7 * 7, 7, 28);
}

BusinessGreetingMessage::BusinessGreetingMessage(
    td_api::object_ptr<td_api::businessGreetingMessageSettings> greeting_message) {
  if (greeting_message == nullptr) {
    return;
  }
  auto inactivity_days = greeting_message->inactivity_days_;
  if (inactivity_days < 7 || inactivity_days > 28 || inactivity_days % 7 != 0) {
    return;
  }
  shortcut_id_ = QuickReplyShortcutId(greeting_message->shortcut_id_);
  recipients_ = BusinessRecipients(std::move(greeting_message->recipients_), false);
  inactivity_days_ = inactivity_days;
}

td_api::object_ptr<td_api::businessGreetingMessageSettings>
BusinessGreetingMessage::get_business_greeting_message_settings_object(Td *td) const {
  if (is_empty()) {
    return nullptr;
  }
  return td_api::make_object<td_api::businessGreetingMessageSettings>(
      shortcut_id_.get(), recipients_.get_business_recipients_object(td), inactivity_days_);
}

telegram_api::object_ptr<telegram_api::inputBusinessGreetingMessage>
BusinessGreetingMessage::get_input_business_greeting_message(Td *td) const {
  return telegram_api::make_object<telegram_api::inputBusinessGreetingMessage>(
      shortcut_id_.get(), recipients_.get_input_business_recipients(td), inactivity_days_);
}

void BusinessGreetingMessage::add_dependencies(Dependencies &dependencies) const {
  recipients_.add_dependencies(dependencies);
}

bool operator==(const BusinessGreetingMessage &lhs, const BusinessGreetingMessage &rhs) {
  return lhs.shortcut_id_ == rhs.shortcut_id_ && lhs.recipients_ == rhs.recipients_ &&
         lhs.inactivity_days_ == rhs.inactivity_days_;
}

StringBuilder &operator<<(StringBuilder &string_builder, const BusinessGreetingMessage &greeting_message) {
  return string_builder << "greeting message " << greeting_message.shortcut_id_ << ' ' << greeting_message.recipients_
                        << " after " << greeting_message.inactivity_days_ << " inactivity days";
}

}  // namespace td
