//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"

#include "td/utils/common.h"
#include "td/utils/StringBuilder.h"

namespace td {

class BusinessBotRights {
 public:
  BusinessBotRights() = default;

  explicit BusinessBotRights(const telegram_api::object_ptr<telegram_api::businessBotRights> &bot_rights);

  explicit BusinessBotRights(const td_api::object_ptr<td_api::businessBotRights> &bot_rights);

  static BusinessBotRights legacy(bool can_reply);

  td_api::object_ptr<td_api::businessBotRights> get_business_bot_rights_object() const;

  telegram_api::object_ptr<telegram_api::businessBotRights> get_input_business_bot_rights() const;

  template <class StorerT>
  void store(StorerT &storer) const;

  template <class ParserT>
  void parse(ParserT &parser);

 private:
  bool can_reply_ = false;
  bool can_read_messages_ = false;
  bool can_delete_sent_messages_ = false;
  bool can_delete_received_messages_ = false;
  bool can_edit_name_ = false;
  bool can_edit_bio_ = false;
  bool can_edit_profile_photo_ = false;
  bool can_edit_username_ = false;
  bool can_view_gifts_ = false;
  bool can_sell_gifts_ = false;
  bool can_change_gift_settings_ = false;
  bool can_transfer_and_upgrade_gifts_ = false;
  bool can_transfer_stars_ = false;
  bool can_manage_stories_ = false;

  friend bool operator==(const BusinessBotRights &lhs, const BusinessBotRights &rhs);

  friend StringBuilder &operator<<(StringBuilder &string_builder, const BusinessBotRights &bot_rights);
};

bool operator==(const BusinessBotRights &lhs, const BusinessBotRights &rhs);

inline bool operator!=(const BusinessBotRights &lhs, const BusinessBotRights &rhs) {
  return !(lhs == rhs);
}

StringBuilder &operator<<(StringBuilder &string_builder, const BusinessBotRights &bot_rights);

}  // namespace td
