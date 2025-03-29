//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/BusinessAwayMessageSchedule.h"
#include "td/telegram/BusinessRecipients.h"
#include "td/telegram/QuickReplyShortcutId.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"

#include "td/utils/common.h"
#include "td/utils/StringBuilder.h"

namespace td {

class Dependencies;
class Td;

class BusinessAwayMessage {
 public:
  BusinessAwayMessage() = default;

  explicit BusinessAwayMessage(telegram_api::object_ptr<telegram_api::businessAwayMessage> away_message);

  explicit BusinessAwayMessage(td_api::object_ptr<td_api::businessAwayMessageSettings> away_message);

  td_api::object_ptr<td_api::businessAwayMessageSettings> get_business_away_message_settings_object(Td *td) const;

  telegram_api::object_ptr<telegram_api::inputBusinessAwayMessage> get_input_business_away_message(Td *td) const;

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
  BusinessAwayMessageSchedule schedule_;
  bool offline_only_ = false;

  friend bool operator==(const BusinessAwayMessage &lhs, const BusinessAwayMessage &rhs);

  friend StringBuilder &operator<<(StringBuilder &string_builder, const BusinessAwayMessage &away_message);
};

bool operator==(const BusinessAwayMessage &lhs, const BusinessAwayMessage &rhs);

inline bool operator!=(const BusinessAwayMessage &lhs, const BusinessAwayMessage &rhs) {
  return !(lhs == rhs);
}

StringBuilder &operator<<(StringBuilder &string_builder, const BusinessAwayMessage &away_message);

}  // namespace td
