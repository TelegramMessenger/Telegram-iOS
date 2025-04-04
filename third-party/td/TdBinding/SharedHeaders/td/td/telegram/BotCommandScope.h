//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/DialogId.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/UserId.h"

#include "td/utils/common.h"
#include "td/utils/Status.h"

namespace td {

class Td;

class BotCommandScope {
  enum class Type : int32 {
    Default,
    AllUsers,
    AllChats,
    AllChatAdministrators,
    Dialog,
    DialogAdministrators,
    DialogParticipant
  };
  Type type_ = Type::Default;
  DialogId dialog_id_;
  UserId user_id_;

  explicit BotCommandScope(Type type, DialogId dialog_id = DialogId(), UserId user_id = UserId());

 public:
  static Result<BotCommandScope> get_bot_command_scope(Td *td, td_api::object_ptr<td_api::BotCommandScope> scope_ptr);

  telegram_api::object_ptr<telegram_api::BotCommandScope> get_input_bot_command_scope(const Td *td) const;
};

}  // namespace td
