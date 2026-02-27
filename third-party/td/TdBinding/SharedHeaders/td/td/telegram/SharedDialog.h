//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/DialogId.h"
#include "td/telegram/Photo.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"

#include "td/utils/common.h"
#include "td/utils/StringBuilder.h"

namespace td {

class Td;

class SharedDialog {
 public:
  SharedDialog() = default;

  explicit SharedDialog(DialogId dialog_id) : dialog_id_(dialog_id) {
  }

  SharedDialog(Td *td, telegram_api::object_ptr<telegram_api::RequestedPeer> &&requested_peer_ptr);

  bool is_valid() const {
    return dialog_id_.is_valid();
  }

  bool is_user() const {
    return dialog_id_.get_type() == DialogType::User;
  }

  bool is_dialog() const {
    auto dialog_type = dialog_id_.get_type();
    return dialog_type == DialogType::Chat || dialog_type == DialogType::Channel;
  }

  td_api::object_ptr<td_api::sharedUser> get_shared_user_object(Td *td) const;

  td_api::object_ptr<td_api::sharedChat> get_shared_chat_object(Td *td) const;

  template <class StorerT>
  void store(StorerT &storer) const;

  template <class ParserT>
  void parse(ParserT &parser);

 private:
  friend bool operator==(const SharedDialog &lhs, const SharedDialog &rhs);
  friend bool operator!=(const SharedDialog &lhs, const SharedDialog &rhs);

  friend StringBuilder &operator<<(StringBuilder &string_builder, const SharedDialog &shared_dialog);

  DialogId dialog_id_;
  string first_name_;
  string last_name_;
  string username_;
  Photo photo_;
};

bool operator==(const SharedDialog &lhs, const SharedDialog &rhs);
bool operator!=(const SharedDialog &lhs, const SharedDialog &rhs);

StringBuilder &operator<<(StringBuilder &string_builder, const SharedDialog &shared_dialog);

}  // namespace td
