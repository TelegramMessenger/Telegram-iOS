//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/CustomEmojiId.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/UserId.h"

#include "td/utils/common.h"
#include "td/utils/StringBuilder.h"

namespace td {

class Dependencies;
class Td;

class BotVerification {
 public:
  BotVerification() = default;

  explicit BotVerification(telegram_api::object_ptr<telegram_api::botVerification> &&bot_verification);

  static unique_ptr<BotVerification> get_bot_verification(
      telegram_api::object_ptr<telegram_api::botVerification> &&bot_verification);

  td_api::object_ptr<td_api::botVerification> get_bot_verification_object(Td *td) const;

  bool is_valid() const {
    return bot_user_id_.is_valid() && icon_.is_valid();
  }

  void add_dependencies(Dependencies &dependencies) const;

  template <class StorerT>
  void store(StorerT &storer) const;

  template <class ParserT>
  void parse(ParserT &parser);

 private:
  UserId bot_user_id_;
  CustomEmojiId icon_;
  string description_;

  friend bool operator==(const BotVerification &lhs, const BotVerification &rhs);

  friend StringBuilder &operator<<(StringBuilder &string_builder, const BotVerification &bot_verification);
};

bool operator==(const BotVerification &lhs, const BotVerification &rhs);

StringBuilder &operator<<(StringBuilder &string_builder, const BotVerification &bot_verification);

}  // namespace td
