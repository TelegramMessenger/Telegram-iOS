//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/SecretInputMedia.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/UserId.h"
#include "td/telegram/Version.h"

#include "td/utils/common.h"
#include "td/utils/HashTableUtils.h"
#include "td/utils/Status.h"
#include "td/utils/StringBuilder.h"
#include "td/utils/tl_helpers.h"

#include <tuple>

namespace td {

class Td;

class Contact {
  string phone_number_;
  string first_name_;
  string last_name_;
  string vcard_;
  UserId user_id_;

  friend bool operator==(const Contact &lhs, const Contact &rhs);
  friend bool operator!=(const Contact &lhs, const Contact &rhs);

  friend StringBuilder &operator<<(StringBuilder &string_builder, const Contact &contact);

  friend struct ContactEqual;
  friend struct ContactHash;

 public:
  Contact() = default;

  Contact(string phone_number, string first_name, string last_name, string vcard, UserId user_id);

  void set_user_id(UserId user_id);

  UserId get_user_id() const;

  const string &get_phone_number() const;

  const string &get_first_name() const;

  const string &get_last_name() const;

  tl_object_ptr<td_api::contact> get_contact_object(Td *td) const;

  tl_object_ptr<telegram_api::inputMediaContact> get_input_media_contact() const;

  SecretInputMedia get_secret_input_media_contact() const;

  tl_object_ptr<telegram_api::inputPhoneContact> get_input_phone_contact(int64 client_id) const;

  tl_object_ptr<telegram_api::inputBotInlineMessageMediaContact> get_input_bot_inline_message_media_contact(
      tl_object_ptr<telegram_api::ReplyMarkup> &&reply_markup) const;

  template <class StorerT>
  void store(StorerT &storer) const {
    using td::store;
    bool has_first_name = !first_name_.empty();
    bool has_last_name = !last_name_.empty();
    bool has_vcard = !vcard_.empty();
    bool has_user_id = user_id_.is_valid();
    BEGIN_STORE_FLAGS();
    STORE_FLAG(has_first_name);
    STORE_FLAG(has_last_name);
    STORE_FLAG(has_vcard);
    STORE_FLAG(has_user_id);
    END_STORE_FLAGS();
    store(phone_number_, storer);
    if (has_first_name) {
      store(first_name_, storer);
    }
    if (has_last_name) {
      store(last_name_, storer);
    }
    if (has_vcard) {
      store(vcard_, storer);
    }
    if (has_user_id) {
      store(user_id_, storer);
    }
  }

  template <class ParserT>
  void parse(ParserT &parser) {
    using td::parse;
    bool has_first_name = true;
    bool has_last_name = true;
    bool has_vcard = false;
    bool has_user_id = true;
    if (parser.version() >= static_cast<int32>(Version::AddContactVcard)) {
      BEGIN_PARSE_FLAGS();
      PARSE_FLAG(has_first_name);
      PARSE_FLAG(has_last_name);
      PARSE_FLAG(has_vcard);
      PARSE_FLAG(has_user_id);
      END_PARSE_FLAGS();
    }
    parse(phone_number_, parser);
    if (has_first_name) {
      parse(first_name_, parser);
    }
    if (has_last_name) {
      parse(last_name_, parser);
    }
    if (has_vcard) {
      parse(vcard_, parser);
    }
    if (has_user_id) {
      parse(user_id_, parser);
    }
  }
};

bool operator==(const Contact &lhs, const Contact &rhs);
bool operator!=(const Contact &lhs, const Contact &rhs);

StringBuilder &operator<<(StringBuilder &string_builder, const Contact &contact);

struct ContactEqual {
  bool operator()(const Contact &lhs, const Contact &rhs) const {
    return std::tie(lhs.phone_number_, lhs.first_name_, lhs.last_name_) ==
           std::tie(rhs.phone_number_, rhs.first_name_, rhs.last_name_);
  }
};

struct ContactHash {
  uint32 operator()(const Contact &contact) const {
    return combine_hashes(combine_hashes(Hash<string>()(contact.phone_number_), Hash<string>()(contact.first_name_)),
                          Hash<string>()(contact.last_name_));
  }
};

Result<Contact> get_contact(Td *td, td_api::object_ptr<td_api::contact> &&contact) TD_WARN_UNUSED_RESULT;

Result<Contact> process_input_message_contact(
    Td *td, td_api::object_ptr<td_api::InputMessageContent> &&input_message_content) TD_WARN_UNUSED_RESULT;

}  // namespace td
