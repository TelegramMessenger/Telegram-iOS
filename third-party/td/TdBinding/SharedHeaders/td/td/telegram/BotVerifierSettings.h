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

#include "td/utils/common.h"
#include "td/utils/StringBuilder.h"

namespace td {

class Td;

class BotVerifierSettings {
 public:
  BotVerifierSettings() = default;

  explicit BotVerifierSettings(telegram_api::object_ptr<telegram_api::botVerifierSettings> &&bot_verifier_settings);

  static unique_ptr<BotVerifierSettings> get_bot_verifier_settings(
      telegram_api::object_ptr<telegram_api::botVerifierSettings> &&bot_verifier_settings);

  td_api::object_ptr<td_api::botVerificationParameters> get_bot_verification_parameters_object(Td *td) const;

  bool is_valid() const {
    return icon_.is_valid();
  }

  template <class StorerT>
  void store(StorerT &storer) const;

  template <class ParserT>
  void parse(ParserT &parser);

 private:
  CustomEmojiId icon_;
  string company_;
  string description_;
  bool can_modify_custom_description_ = false;

  friend bool operator==(const BotVerifierSettings &lhs, const BotVerifierSettings &rhs);

  friend StringBuilder &operator<<(StringBuilder &string_builder, const BotVerifierSettings &bot_verifier_settings);
};

bool operator==(const BotVerifierSettings &lhs, const BotVerifierSettings &rhs);

StringBuilder &operator<<(StringBuilder &string_builder, const BotVerifierSettings &bot_verifier_settings);

}  // namespace td
