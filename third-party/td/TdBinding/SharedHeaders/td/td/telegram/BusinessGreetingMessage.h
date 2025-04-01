//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/BusinessRecipients.h"
#include "td/telegram/QuickReplyShortcutId.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"

#include "td/utils/common.h"
#include "td/utils/StringBuilder.h"

namespace td {

class Dependencies;
class Td;

class BusinessGreetingMessage {
 public:
  BusinessGreetingMessage() = default;

  explicit BusinessGreetingMessage(telegram_api::object_ptr<telegram_api::businessGreetingMessage> greeting_message);

  explicit BusinessGreetingMessage(td_api::object_ptr<td_api::businessGreetingMessageSettings> greeting_message);

  td_api::object_ptr<td_api::businessGreetingMessageSettings> get_business_greeting_message_settings_object(
      Td *td) const;

  telegram_api::object_ptr<telegram_api::inputBusinessGreetingMessage> get_input_business_greeting_message(
      Td *td) const;

  bool is_empty() const {
    return !is_valid();
  }

  bool is_valid() const {
    return shortcut_id_.is_server();
  }

  void add_dependencies(Dependencies &dependencies) const;

  template <class StorerT>
  void store(StorerT &storer) const;

  template <class ParserT>
  void parse(ParserT &parser);

 private:
  QuickReplyShortcutId shortcut_id_;
  BusinessRecipients recipients_;
  int32 inactivity_days_ = 0;

  friend bool operator==(const BusinessGreetingMessage &lhs, const BusinessGreetingMessage &rhs);

  friend StringBuilder &operator<<(StringBuilder &string_builder, const BusinessGreetingMessage &greeting_message);
};

bool operator==(const BusinessGreetingMessage &lhs, const BusinessGreetingMessage &rhs);

inline bool operator!=(const BusinessGreetingMessage &lhs, const BusinessGreetingMessage &rhs) {
  return !(lhs == rhs);
}

StringBuilder &operator<<(StringBuilder &string_builder, const BusinessGreetingMessage &greeting_message);

}  // namespace td
