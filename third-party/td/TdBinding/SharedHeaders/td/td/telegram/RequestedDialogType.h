//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/DialogId.h"
#include "td/telegram/DialogParticipant.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"

#include "td/utils/common.h"
#include "td/utils/Status.h"

namespace td {

class Td;

class RequestedDialogType {
  enum class Type : int32 { User, Group, Channel };
  Type type_ = Type::User;
  int32 button_id_ = 0;
  int32 max_quantity_ = 1;            // User only
  bool restrict_is_bot_ = false;      // User only
  bool is_bot_ = false;               // User only
  bool restrict_is_premium_ = false;  // User only
  bool is_premium_ = false;           // User only

  bool request_name_ = false;
  bool request_username_ = false;
  bool request_photo_ = false;

  bool restrict_is_forum_ = false;                   // Group only
  bool is_forum_ = false;                            // Group only
  bool bot_is_participant_ = false;                  // Group only
  bool restrict_has_username_ = false;               // Group and Channel only
  bool has_username_ = false;                        // Group and Channel only
  bool is_created_ = false;                          // Group and Channel only
  bool restrict_user_administrator_rights_ = false;  // Group and Channel only
  bool restrict_bot_administrator_rights_ = false;   // Group and Channel only
  AdministratorRights user_administrator_rights_;    // Group and Channel only
  AdministratorRights bot_administrator_rights_;     // Group and Channel only

  telegram_api::object_ptr<telegram_api::RequestPeerType> get_input_request_peer_type_object() const;

 public:
  RequestedDialogType() = default;

  explicit RequestedDialogType(td_api::object_ptr<td_api::keyboardButtonTypeRequestUsers> &&request_users);

  explicit RequestedDialogType(td_api::object_ptr<td_api::keyboardButtonTypeRequestChat> &&request_dialog);

  RequestedDialogType(telegram_api::object_ptr<telegram_api::RequestPeerType> &&peer_type, int32 button_id,
                      int32 max_quantity);

  td_api::object_ptr<td_api::KeyboardButtonType> get_keyboard_button_type_object() const;

  telegram_api::object_ptr<telegram_api::inputKeyboardButtonRequestPeer> get_input_keyboard_button_request_peer(
      const string &text) const;

  int32 get_button_id() const;

  Status check_shared_dialog(Td *td, DialogId dialog_id) const;

  Status check_shared_dialog_count(size_t count) const;

  template <class StorerT>
  void store(StorerT &storer) const;

  template <class ParserT>
  void parse(ParserT &parser);
};

}  // namespace td
