//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/BusinessBotRights.h"

namespace td {

BusinessBotRights::BusinessBotRights(const telegram_api::object_ptr<telegram_api::businessBotRights> &bot_rights) {
  if (bot_rights == nullptr) {
    return;
  }
  can_reply_ = bot_rights->reply_;
  can_read_messages_ = bot_rights->read_messages_;
  can_delete_sent_messages_ = bot_rights->delete_sent_messages_;
  can_delete_received_messages_ = bot_rights->delete_received_messages_;
  can_edit_name_ = bot_rights->edit_name_;
  can_edit_bio_ = bot_rights->edit_bio_;
  can_edit_profile_photo_ = bot_rights->edit_profile_photo_;
  can_edit_username_ = bot_rights->edit_username_;
  can_view_gifts_ = bot_rights->view_gifts_;
  can_sell_gifts_ = bot_rights->sell_gifts_;
  can_change_gift_settings_ = bot_rights->change_gift_settings_;
  can_transfer_and_upgrade_gifts_ = bot_rights->transfer_and_upgrade_gifts_;
  can_transfer_stars_ = bot_rights->transfer_stars_;
  can_manage_stories_ = bot_rights->manage_stories_;
}

BusinessBotRights::BusinessBotRights(const td_api::object_ptr<td_api::businessBotRights> &bot_rights) {
  if (bot_rights == nullptr) {
    return;
  }
  can_reply_ = bot_rights->can_reply_;
  can_read_messages_ = bot_rights->can_read_messages_;
  can_delete_sent_messages_ = bot_rights->can_delete_sent_messages_;
  can_delete_received_messages_ = bot_rights->can_delete_all_messages_;
  can_edit_name_ = bot_rights->can_edit_name_;
  can_edit_bio_ = bot_rights->can_edit_bio_;
  can_edit_profile_photo_ = bot_rights->can_edit_profile_photo_;
  can_edit_username_ = bot_rights->can_edit_username_;
  can_view_gifts_ = bot_rights->can_view_gifts_and_stars_;
  can_sell_gifts_ = bot_rights->can_sell_gifts_;
  can_change_gift_settings_ = bot_rights->can_change_gift_settings_;
  can_transfer_and_upgrade_gifts_ = bot_rights->can_transfer_and_upgrade_gifts_;
  can_transfer_stars_ = bot_rights->can_transfer_stars_;
  can_manage_stories_ = bot_rights->can_manage_stories_;
}

BusinessBotRights BusinessBotRights::legacy(bool can_reply) {
  BusinessBotRights result;
  result.can_reply_ = can_reply;
  return result;
}

td_api::object_ptr<td_api::businessBotRights> BusinessBotRights::get_business_bot_rights_object() const {
  return td_api::make_object<td_api::businessBotRights>(
      can_reply_, can_read_messages_, can_delete_sent_messages_, can_delete_received_messages_, can_edit_name_,
      can_edit_bio_, can_edit_profile_photo_, can_edit_username_, can_view_gifts_, can_sell_gifts_,
      can_change_gift_settings_, can_transfer_and_upgrade_gifts_, can_transfer_stars_, can_manage_stories_);
}

telegram_api::object_ptr<telegram_api::businessBotRights> BusinessBotRights::get_input_business_bot_rights() const {
  return telegram_api::make_object<telegram_api::businessBotRights>(
      0, can_reply_, can_read_messages_, can_delete_sent_messages_, can_delete_received_messages_, can_edit_name_,
      can_edit_bio_, can_edit_profile_photo_, can_edit_username_, can_view_gifts_, can_sell_gifts_,
      can_change_gift_settings_, can_transfer_and_upgrade_gifts_, can_transfer_stars_, can_manage_stories_);
}

bool operator==(const BusinessBotRights &lhs, const BusinessBotRights &rhs) {
  return lhs.can_reply_ == rhs.can_reply_ && lhs.can_read_messages_ == rhs.can_read_messages_ &&
         lhs.can_delete_sent_messages_ == rhs.can_delete_sent_messages_ &&
         lhs.can_delete_received_messages_ == rhs.can_delete_received_messages_ &&
         lhs.can_edit_name_ == rhs.can_edit_name_ && lhs.can_edit_bio_ == rhs.can_edit_bio_ &&
         lhs.can_edit_profile_photo_ == rhs.can_edit_profile_photo_ &&
         lhs.can_edit_username_ == rhs.can_edit_username_ && lhs.can_view_gifts_ == rhs.can_view_gifts_ &&
         lhs.can_sell_gifts_ == rhs.can_sell_gifts_ && lhs.can_change_gift_settings_ == rhs.can_change_gift_settings_ &&
         lhs.can_transfer_and_upgrade_gifts_ == rhs.can_transfer_and_upgrade_gifts_ &&
         lhs.can_transfer_stars_ == rhs.can_transfer_stars_ && lhs.can_manage_stories_ == rhs.can_manage_stories_;
}

StringBuilder &operator<<(StringBuilder &string_builder, const BusinessBotRights &bot_rights) {
  string_builder << "BusinessBotRights";
  if (bot_rights.can_reply_) {
    string_builder << "(reply)";
  }
  if (bot_rights.can_read_messages_) {
    string_builder << "(read_messages)";
  }
  if (bot_rights.can_delete_sent_messages_) {
    string_builder << "(delete_sent_messages)";
  }
  if (bot_rights.can_delete_received_messages_) {
    string_builder << "(delete_received_messages)";
  }
  if (bot_rights.can_edit_name_) {
    string_builder << "(edit_name)";
  }
  if (bot_rights.can_edit_bio_) {
    string_builder << "(edit_bio)";
  }
  if (bot_rights.can_edit_profile_photo_) {
    string_builder << "(edit_profile_photo)";
  }
  if (bot_rights.can_edit_username_) {
    string_builder << "(edit_username)";
  }
  if (bot_rights.can_view_gifts_) {
    string_builder << "(view_gifts)";
  }
  if (bot_rights.can_sell_gifts_) {
    string_builder << "(sell_gifts)";
  }
  if (bot_rights.can_change_gift_settings_) {
    string_builder << "(change_gift_settings)";
  }
  if (bot_rights.can_transfer_and_upgrade_gifts_) {
    string_builder << "(transfer_and_upgrade_gifts)";
  }
  if (bot_rights.can_transfer_stars_) {
    string_builder << "(transfer_stars)";
  }
  if (bot_rights.can_manage_stories_) {
    string_builder << "(manage_stories)";
  }
  return string_builder << ']';
}

}  // namespace td
