//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/DialogActionBar.h"

#include "td/telegram/ChatManager.h"
#include "td/telegram/Td.h"
#include "td/telegram/UserManager.h"

#include "td/utils/logging.h"
#include "td/utils/misc.h"

namespace td {

unique_ptr<DialogActionBar> DialogActionBar::create_legacy(bool can_report_spam, bool can_add_contact,
                                                           bool can_block_user, bool can_share_phone_number,
                                                           bool can_report_location, bool can_unarchive, int32 distance,
                                                           bool can_invite_members) {
  auto action_bar = make_unique<DialogActionBar>();
  action_bar->can_report_spam_ = can_report_spam;
  action_bar->can_add_contact_ = can_add_contact;
  action_bar->can_block_user_ = can_block_user;
  action_bar->can_share_phone_number_ = can_share_phone_number;
  action_bar->can_report_location_ = can_report_location;
  action_bar->can_unarchive_ = can_unarchive;
  action_bar->distance_ = distance >= 0 ? distance : -1;
  action_bar->can_invite_members_ = can_invite_members;
  if (action_bar->is_empty()) {
    return nullptr;
  }
  return action_bar;
}

unique_ptr<DialogActionBar> DialogActionBar::create(
    telegram_api::object_ptr<telegram_api::peerSettings> peer_settings) {
  if (peer_settings == nullptr) {
    return nullptr;
  }

  auto action_bar = make_unique<DialogActionBar>();
  action_bar->can_report_spam_ = peer_settings->report_spam_;
  action_bar->can_add_contact_ = peer_settings->add_contact_;
  action_bar->can_block_user_ = peer_settings->block_contact_;
  action_bar->can_share_phone_number_ = peer_settings->share_contact_;
  action_bar->can_report_location_ = peer_settings->report_geo_;
  action_bar->can_unarchive_ = peer_settings->autoarchived_;
  if ((peer_settings->flags_ & telegram_api::peerSettings::GEO_DISTANCE_MASK) != 0 &&
      peer_settings->geo_distance_ >= 0) {
    action_bar->distance_ = peer_settings->geo_distance_;
  }
  action_bar->can_invite_members_ = peer_settings->invite_members_;
  action_bar->join_request_dialog_title_ = std::move(peer_settings->request_chat_title_);
  action_bar->is_join_request_broadcast_ = peer_settings->request_chat_broadcast_;
  action_bar->join_request_date_ = peer_settings->request_chat_date_;
  if (!parse_registration_month(action_bar->registration_month_, peer_settings->registration_month_)) {
    LOG(ERROR) << "Receive invalid registration month " << peer_settings->registration_month_;
  }
  if (!parse_country_code(action_bar->phone_country_, peer_settings->phone_country_)) {
    LOG(ERROR) << "Receive invalid phone number country code " << peer_settings->phone_country_;
  }
  action_bar->last_name_change_date_ = max(0, peer_settings->name_change_date_);
  action_bar->last_photo_change_date_ = max(0, peer_settings->photo_change_date_);
  if (action_bar->is_empty()) {
    return nullptr;
  }
  return action_bar;
}

bool DialogActionBar::is_empty() const {
  return !can_report_spam_ && !can_add_contact_ && !can_block_user_ && !can_share_phone_number_ &&
         !can_report_location_ && !can_invite_members_ && join_request_dialog_title_.empty();
}

bool DialogActionBar::parse_registration_month(int32 &registration_month, const string &str) {
  if (str.empty()) {
    return true;
  }
  if (str.size() != 7u || !is_digit(str[0]) || !is_digit(str[1]) || str[2] != '.' || !is_digit(str[3]) ||
      !is_digit(str[4]) || !is_digit(str[5]) || !is_digit(str[6])) {
    return false;
  }
  auto month_int = (str[0] - '0') * 10 + (str[1] - '0');
  auto year_int = (str[3] - '0') * 1000 + (str[4] - '0') * 100 + (str[5] - '0') * 10 + (str[6] - '0');
  if (month_int < 1 || month_int > 12 || year_int < 2000) {
    return false;
  }
  registration_month = month_int * 10000 + year_int;
  return true;
}

bool DialogActionBar::parse_country_code(int32 &country_code, const string &str) {
  if (str.empty()) {
    return true;
  }
  if (str.size() != 2u || str[0] < 'A' || str[0] > 'Z' || str[1] < 'A' || str[1] > 'Z') {
    return false;
  }
  country_code = str[0] * 256 + str[1];
  return true;
}

string DialogActionBar::get_country_code(int32 country) {
  auto first_char = (country >> 8) & 255;
  auto second_char = country & 255;
  if (first_char < 'A' || first_char > 'Z' || second_char < 'A' || second_char > 'Z') {
    return string();
  }
  string result(2, static_cast<char>(first_char));
  result[1] = static_cast<char>(second_char);
  return result;
}

void DialogActionBar::clear_can_block_user() {
  can_block_user_ = false;
  registration_month_ = 0;
  phone_country_ = 0;
  last_name_change_date_ = 0;
  last_photo_change_date_ = 0;
}

void DialogActionBar::fix(Td *td, DialogId dialog_id, bool is_dialog_blocked, bool has_outgoing_messages,
                          FolderId folder_id) {
  auto dialog_type = dialog_id.get_type();
  if (distance_ >= 0) {
    if (dialog_type != DialogType::User) {
      LOG(ERROR) << "Receive distance " << distance_ << " to " << dialog_id;
      distance_ = -1;
    } else if (has_outgoing_messages) {
      distance_ = -1;
    }
  }

  if (!join_request_dialog_title_.empty()) {
    if (dialog_type != DialogType::User || join_request_date_ <= 0) {
      LOG(ERROR) << "Receive join_request_date = " << join_request_date_ << " in " << dialog_id;
      join_request_dialog_title_.clear();
      is_join_request_broadcast_ = false;
      join_request_date_ = 0;
    } else if (can_report_location_ || can_report_spam_ || can_add_contact_ || can_block_user_ ||
               can_share_phone_number_ || can_unarchive_ || can_invite_members_) {
      LOG(ERROR) << "Receive action bar " << can_report_location_ << '/' << can_report_spam_ << '/' << can_add_contact_
                 << '/' << can_block_user_ << '/' << can_share_phone_number_ << '/' << can_report_location_ << '/'
                 << can_unarchive_ << '/' << can_invite_members_;
      can_report_location_ = false;
      can_report_spam_ = false;
      can_add_contact_ = false;
      clear_can_block_user();
      can_share_phone_number_ = false;
      can_unarchive_ = false;
      can_invite_members_ = false;
      distance_ = -1;
    } else {
      // ignore
      registration_month_ = 0;
      phone_country_ = 0;
      last_name_change_date_ = 0;
      last_photo_change_date_ = 0;
    }
  }
  if ((registration_month_ != 0 || phone_country_ != 0 || last_name_change_date_ != 0 ||
       last_photo_change_date_ != 0) &&
      !can_block_user_) {
    LOG(ERROR) << "Receive account information in the action bar " << can_report_spam_ << '/' << can_add_contact_ << '/'
               << can_block_user_ << '/' << can_share_phone_number_ << '/' << can_report_location_ << '/'
               << can_unarchive_ << '/' << can_invite_members_;
    registration_month_ = 0;
    phone_country_ = 0;
    last_name_change_date_ = 0;
    last_photo_change_date_ = 0;
  }
  if (join_request_dialog_title_.empty() && (is_join_request_broadcast_ || join_request_date_ != 0)) {
    LOG(ERROR) << "Receive join request date = " << join_request_date_ << " and " << is_join_request_broadcast_
               << " in " << dialog_id;
    is_join_request_broadcast_ = false;
    join_request_date_ = 0;
  }
  if (can_report_location_) {
    if (dialog_type != DialogType::Channel) {
      LOG(ERROR) << "Receive can_report_location in " << dialog_id;
      can_report_location_ = false;
    } else if (can_report_spam_ || can_add_contact_ || can_block_user_ || can_share_phone_number_ || can_unarchive_ ||
               can_invite_members_) {
      LOG(ERROR) << "Receive action bar " << can_report_spam_ << '/' << can_add_contact_ << '/' << can_block_user_
                 << '/' << can_share_phone_number_ << '/' << can_report_location_ << '/' << can_unarchive_ << '/'
                 << can_invite_members_;
      can_report_spam_ = false;
      can_add_contact_ = false;
      clear_can_block_user();
      can_share_phone_number_ = false;
      can_unarchive_ = false;
      can_invite_members_ = false;
      CHECK(distance_ == -1);
    }
  }
  if (can_invite_members_) {
    if (dialog_type != DialogType::Chat &&
        (dialog_type != DialogType::Channel || td->chat_manager_->is_broadcast_channel(dialog_id.get_channel_id()))) {
      LOG(ERROR) << "Receive can_invite_members in " << dialog_id;
      can_invite_members_ = false;
    } else if (can_report_spam_ || can_add_contact_ || can_block_user_ || can_share_phone_number_ || can_unarchive_) {
      LOG(ERROR) << "Receive action bar " << can_report_spam_ << '/' << can_add_contact_ << '/' << can_block_user_
                 << '/' << can_share_phone_number_ << '/' << can_unarchive_ << '/' << can_invite_members_;
      can_report_spam_ = false;
      can_add_contact_ = false;
      clear_can_block_user();
      can_share_phone_number_ = false;
      can_unarchive_ = false;
      CHECK(distance_ == -1);
    }
  }
  if (dialog_type == DialogType::User) {
    auto user_id = dialog_id.get_user_id();
    bool is_me = user_id == td->user_manager_->get_my_id();
    bool is_deleted = td->user_manager_->is_user_deleted(user_id);
    bool is_contact = td->user_manager_->is_user_contact(user_id);
    if (is_me || is_dialog_blocked) {
      can_report_spam_ = false;
      can_unarchive_ = false;
    }
    if (is_me || is_dialog_blocked || is_deleted) {
      can_share_phone_number_ = false;
    }
    if (is_me || is_dialog_blocked || is_deleted || is_contact) {
      clear_can_block_user();
      can_add_contact_ = false;
    }
  }
  if (folder_id != FolderId::archive()) {
    can_unarchive_ = false;
  }
  if (can_share_phone_number_) {
    CHECK(!can_report_location_);
    CHECK(!can_invite_members_);
    if (dialog_type != DialogType::User) {
      LOG(ERROR) << "Receive can_share_phone_number in " << dialog_id;
      can_share_phone_number_ = false;
    } else if (can_report_spam_ || can_add_contact_ || can_block_user_ || can_unarchive_ || distance_ >= 0) {
      LOG(ERROR) << "Receive action bar " << can_report_spam_ << '/' << can_add_contact_ << '/' << can_block_user_
                 << '/' << can_share_phone_number_ << '/' << can_unarchive_ << '/' << distance_;
      can_report_spam_ = false;
      can_add_contact_ = false;
      clear_can_block_user();
      can_unarchive_ = false;
    }
  }
  if (can_block_user_) {
    CHECK(!can_report_location_);
    CHECK(!can_invite_members_);
    CHECK(!can_share_phone_number_);
    if (dialog_type != DialogType::User) {
      LOG(ERROR) << "Receive can_block_user in " << dialog_id;
      clear_can_block_user();
    } else if (!can_report_spam_ || !can_add_contact_) {
      LOG(ERROR) << "Receive action bar " << can_report_spam_ << '/' << can_add_contact_ << '/' << can_block_user_;
      can_report_spam_ = true;
      can_add_contact_ = true;
    }
  }
  if (can_add_contact_) {
    CHECK(!can_report_location_);
    CHECK(!can_invite_members_);
    CHECK(!can_share_phone_number_);
    if (dialog_type != DialogType::User) {
      LOG(ERROR) << "Receive can_add_contact in " << dialog_id;
      can_add_contact_ = false;
    } else if (can_report_spam_ != can_block_user_) {
      LOG(ERROR) << "Receive action bar " << can_report_spam_ << '/' << can_add_contact_ << '/' << can_block_user_;
      can_report_spam_ = false;
      clear_can_block_user();
      can_unarchive_ = false;
    }
  }
  if (!can_block_user_) {
    distance_ = -1;
  }
  if (!can_report_spam_) {
    can_unarchive_ = false;
  }
}

td_api::object_ptr<td_api::ChatActionBar> DialogActionBar::get_chat_action_bar_object(DialogType dialog_type,
                                                                                      bool hide_unarchive) const {
  if (!join_request_dialog_title_.empty()) {
    CHECK(dialog_type == DialogType::User);
    CHECK(!can_report_location_ && !can_share_phone_number_ && !can_block_user_ && !can_add_contact_ &&
          !can_report_spam_ && !can_invite_members_);
    return td_api::make_object<td_api::chatActionBarJoinRequest>(join_request_dialog_title_, is_join_request_broadcast_,
                                                                 join_request_date_);
  }
  if (can_report_location_) {
    CHECK(dialog_type == DialogType::Channel);
    CHECK(!can_share_phone_number_ && !can_block_user_ && !can_add_contact_ && !can_report_spam_ &&
          !can_invite_members_);
    return nullptr;
  }
  if (can_invite_members_) {
    CHECK(!can_share_phone_number_ && !can_block_user_ && !can_add_contact_ && !can_report_spam_);
    return td_api::make_object<td_api::chatActionBarInviteMembers>();
  }
  if (can_share_phone_number_) {
    CHECK(dialog_type == DialogType::User);
    CHECK(!can_block_user_ && !can_add_contact_ && !can_report_spam_);
    return td_api::make_object<td_api::chatActionBarSharePhoneNumber>();
  }
  if (hide_unarchive) {
    if (can_add_contact_) {
      return td_api::make_object<td_api::chatActionBarAddContact>();
    } else {
      return nullptr;
    }
  }
  if (can_block_user_) {
    CHECK(dialog_type == DialogType::User);
    CHECK(can_report_spam_ && can_add_contact_);
    td_api::object_ptr<td_api::accountInfo> account_info;
    if (registration_month_ > 0 || phone_country_ > 0 || last_name_change_date_ > 0 || last_photo_change_date_ > 0) {
      account_info = td_api::make_object<td_api::accountInfo>(registration_month_ / 10000, registration_month_ % 10000,
                                                              get_country_code(phone_country_), last_name_change_date_,
                                                              last_photo_change_date_);
    }
    return td_api::make_object<td_api::chatActionBarReportAddBlock>(can_unarchive_, std::move(account_info));
  }
  if (can_add_contact_) {
    CHECK(dialog_type == DialogType::User);
    CHECK(!can_report_spam_);
    return td_api::make_object<td_api::chatActionBarAddContact>();
  }
  if (can_report_spam_) {
    return td_api::make_object<td_api::chatActionBarReportSpam>(can_unarchive_);
  }
  return nullptr;
}

bool DialogActionBar::on_dialog_unarchived() {
  if (!can_unarchive_) {
    return false;
  }

  can_unarchive_ = false;
  can_report_spam_ = false;
  clear_can_block_user();
  // keep can_add_contact_
  return true;
}

bool DialogActionBar::on_user_contact_added() {
  if (!can_block_user_ && !can_add_contact_) {
    return false;
  }

  clear_can_block_user();
  can_add_contact_ = false;
  // keep can_unarchive_
  distance_ = -1;
  return true;
}

bool DialogActionBar::on_user_deleted() {
  if (join_request_dialog_title_.empty() && !can_share_phone_number_ && !can_block_user_ && !can_add_contact_ &&
      distance_ < 0) {
    return false;
  }

  join_request_dialog_title_.clear();
  is_join_request_broadcast_ = false;
  join_request_date_ = 0;
  can_share_phone_number_ = false;
  clear_can_block_user();
  can_add_contact_ = false;
  distance_ = -1;
  return true;
}

bool DialogActionBar::on_outgoing_message() {
  if (distance_ < 0) {
    return false;
  }

  distance_ = -1;
  return true;
}

bool operator==(const DialogActionBar &lhs, const DialogActionBar &rhs) {
  return lhs.can_report_spam_ == rhs.can_report_spam_ && lhs.can_add_contact_ == rhs.can_add_contact_ &&
         lhs.can_block_user_ == rhs.can_block_user_ && lhs.can_share_phone_number_ == rhs.can_share_phone_number_ &&
         lhs.can_report_location_ == rhs.can_report_location_ && lhs.can_unarchive_ == rhs.can_unarchive_ &&
         lhs.distance_ == rhs.distance_ && lhs.can_invite_members_ == rhs.can_invite_members_ &&
         lhs.join_request_dialog_title_ == rhs.join_request_dialog_title_ &&
         lhs.is_join_request_broadcast_ == lhs.is_join_request_broadcast_ &&
         lhs.join_request_date_ == rhs.join_request_date_ && lhs.registration_month_ == rhs.registration_month_ &&
         lhs.phone_country_ == rhs.phone_country_ && lhs.last_name_change_date_ == rhs.last_name_change_date_ &&
         lhs.last_photo_change_date_ == rhs.last_photo_change_date_;
}

}  // namespace td
