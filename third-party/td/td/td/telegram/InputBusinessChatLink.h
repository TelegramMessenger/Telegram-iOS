//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/MessageEntity.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"

#include "td/utils/common.h"
#include "td/utils/StringBuilder.h"

namespace td {

class Td;
class UserManager;

class InputBusinessChatLink {
  FormattedText text_;
  string title_;

  friend StringBuilder &operator<<(StringBuilder &string_builder, const InputBusinessChatLink &link);

 public:
  InputBusinessChatLink(const Td *td, td_api::object_ptr<td_api::inputBusinessChatLink> &&link);

  telegram_api::object_ptr<telegram_api::inputBusinessChatLink> get_input_business_chat_link(
      const UserManager *user_manager) const;
};

StringBuilder &operator<<(StringBuilder &string_builder, const InputBusinessChatLink &link);

}  // namespace td
