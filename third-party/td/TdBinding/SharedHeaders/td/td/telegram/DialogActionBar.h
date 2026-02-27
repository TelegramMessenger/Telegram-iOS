//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/DialogId.h"
#include "td/telegram/FolderId.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"

#include "td/utils/common.h"
#include "td/utils/tl_helpers.h"

namespace td {

class Td;

class DialogActionBar {
  int32 distance_ = -1;  // distance to the peer
  int32 join_request_date_ = 0;
  string join_request_dialog_title_;
  int32 registration_month_ = 0;
  int32 phone_country_ = 0;
  int32 last_name_change_date_ = 0;
  int32 last_photo_change_date_ = 0;

  bool can_report_spam_ = false;
  bool can_add_contact_ = false;
  bool can_block_user_ = false;
  bool can_share_phone_number_ = false;
  bool can_report_location_ = false;
  bool can_unarchive_ = false;
  bool can_invite_members_ = false;
  bool is_join_request_broadcast_ = false;

  friend bool operator==(const DialogActionBar &lhs, const DialogActionBar &rhs);

  static bool parse_registration_month(int32 &registration_month, const string &str);

  static bool parse_country_code(int32 &country_code, const string &str);

  static string get_country_code(int32 country);

  void clear_can_block_user();

 public:
  static unique_ptr<DialogActionBar> create_legacy(bool can_report_spam, bool can_add_contact, bool can_block_user,
                                                   bool can_share_phone_number, bool can_report_location,
                                                   bool can_unarchive, int32 distance, bool can_invite_members);

  static unique_ptr<DialogActionBar> create(telegram_api::object_ptr<telegram_api::peerSettings> peer_settings);

  bool is_empty() const;

  bool can_report_spam() const {
    return can_report_spam_;
  }

  bool can_unarchive() const {
    return can_unarchive_;
  }

  td_api::object_ptr<td_api::ChatActionBar> get_chat_action_bar_object(DialogType dialog_type,
                                                                       bool hide_unarchive) const;

  void fix(Td *td, DialogId dialog_id, bool is_dialog_blocked, bool has_outgoing_messages, FolderId folder_id);

  bool on_dialog_unarchived();

  bool on_user_contact_added();

  bool on_user_deleted();

  bool on_outgoing_message();

  template <class StorerT>
  void store(StorerT &storer) const {
    bool has_distance = distance_ >= 0;
    bool has_join_request = !join_request_dialog_title_.empty();
    bool has_registration_month = registration_month_ > 0;
    bool has_phone_country = phone_country_ > 0;
    bool has_last_name_change_date = last_name_change_date_ > 0;
    bool has_last_photo_change_date = last_photo_change_date_ > 0;
    BEGIN_STORE_FLAGS();
    STORE_FLAG(can_report_spam_);
    STORE_FLAG(can_add_contact_);
    STORE_FLAG(can_block_user_);
    STORE_FLAG(can_share_phone_number_);
    STORE_FLAG(can_report_location_);
    STORE_FLAG(can_unarchive_);
    STORE_FLAG(can_invite_members_);
    STORE_FLAG(has_distance);
    STORE_FLAG(is_join_request_broadcast_);
    STORE_FLAG(has_join_request);
    STORE_FLAG(has_registration_month);
    STORE_FLAG(has_phone_country);
    STORE_FLAG(has_last_name_change_date);
    STORE_FLAG(has_last_photo_change_date);
    END_STORE_FLAGS();
    if (has_distance) {
      td::store(distance_, storer);
    }
    if (has_join_request) {
      td::store(join_request_dialog_title_, storer);
      td::store(join_request_date_, storer);
    }
    if (has_registration_month) {
      td::store(registration_month_, storer);
    }
    if (has_phone_country) {
      td::store(phone_country_, storer);
    }
    if (has_last_name_change_date) {
      td::store(last_name_change_date_, storer);
    }
    if (has_last_photo_change_date) {
      td::store(last_photo_change_date_, storer);
    }
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    bool has_distance;
    bool has_join_request;
    bool has_registration_month;
    bool has_phone_country;
    bool has_last_name_change_date;
    bool has_last_photo_change_date;
    BEGIN_PARSE_FLAGS();
    PARSE_FLAG(can_report_spam_);
    PARSE_FLAG(can_add_contact_);
    PARSE_FLAG(can_block_user_);
    PARSE_FLAG(can_share_phone_number_);
    PARSE_FLAG(can_report_location_);
    PARSE_FLAG(can_unarchive_);
    PARSE_FLAG(can_invite_members_);
    PARSE_FLAG(has_distance);
    PARSE_FLAG(is_join_request_broadcast_);
    PARSE_FLAG(has_join_request);
    PARSE_FLAG(has_registration_month);
    PARSE_FLAG(has_phone_country);
    PARSE_FLAG(has_last_name_change_date);
    PARSE_FLAG(has_last_photo_change_date);
    END_PARSE_FLAGS();
    if (has_distance) {
      td::parse(distance_, parser);
    }
    if (has_join_request) {
      td::parse(join_request_dialog_title_, parser);
      td::parse(join_request_date_, parser);
    }
    if (has_registration_month) {
      td::parse(registration_month_, parser);
    }
    if (has_phone_country) {
      td::parse(phone_country_, parser);
    }
    if (has_last_name_change_date) {
      td::parse(last_name_change_date_, parser);
    }
    if (has_last_photo_change_date) {
      td::parse(last_photo_change_date_, parser);
    }
  }
};

bool operator==(const DialogActionBar &lhs, const DialogActionBar &rhs);

}  // namespace td
