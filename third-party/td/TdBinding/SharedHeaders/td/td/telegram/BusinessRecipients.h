//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/UserId.h"

#include "td/utils/common.h"
#include "td/utils/StringBuilder.h"

namespace td {

class Dependencies;
class Td;

class BusinessRecipients {
 public:
  BusinessRecipients() = default;

  explicit BusinessRecipients(telegram_api::object_ptr<telegram_api::businessRecipients> recipients);

  explicit BusinessRecipients(telegram_api::object_ptr<telegram_api::businessBotRecipients> recipients);

  BusinessRecipients(td_api::object_ptr<td_api::businessRecipients> recipients, bool allow_excluded);

  td_api::object_ptr<td_api::businessRecipients> get_business_recipients_object(Td *td) const;

  telegram_api::object_ptr<telegram_api::inputBusinessRecipients> get_input_business_recipients(Td *td) const;

  telegram_api::object_ptr<telegram_api::inputBusinessBotRecipients> get_input_business_bot_recipients(Td *td) const;

  void add_dependencies(Dependencies &dependencies) const;

  template <class StorerT>
  void store(StorerT &storer) const;

  template <class ParserT>
  void parse(ParserT &parser);

 private:
  vector<UserId> user_ids_;
  vector<UserId> excluded_user_ids_;
  bool existing_chats_ = false;
  bool new_chats_ = false;
  bool contacts_ = false;
  bool non_contacts_ = false;
  bool exclude_selected_ = false;

  friend bool operator==(const BusinessRecipients &lhs, const BusinessRecipients &rhs);

  friend StringBuilder &operator<<(StringBuilder &string_builder, const BusinessRecipients &recipients);
};

bool operator==(const BusinessRecipients &lhs, const BusinessRecipients &rhs);

inline bool operator!=(const BusinessRecipients &lhs, const BusinessRecipients &rhs) {
  return !(lhs == rhs);
}

StringBuilder &operator<<(StringBuilder &string_builder, const BusinessRecipients &recipients);

}  // namespace td
