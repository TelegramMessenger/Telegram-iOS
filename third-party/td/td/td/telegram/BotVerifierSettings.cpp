//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/BotVerifierSettings.h"

#include "td/telegram/MessageEntity.h"
#include "td/telegram/Td.h"

#include "td/utils/logging.h"

namespace td {

BotVerifierSettings::BotVerifierSettings(
    telegram_api::object_ptr<telegram_api::botVerifierSettings> &&bot_verifier_settings) {
  if (bot_verifier_settings == nullptr) {
    return;
  }
  icon_ = CustomEmojiId(bot_verifier_settings->icon_);
  company_ = std::move(bot_verifier_settings->company_);
  description_ = std::move(bot_verifier_settings->custom_description_);
  can_modify_custom_description_ = bot_verifier_settings->can_modify_custom_description_;
}

unique_ptr<BotVerifierSettings> BotVerifierSettings::get_bot_verifier_settings(
    telegram_api::object_ptr<telegram_api::botVerifierSettings> &&bot_verifier_settings) {
  if (bot_verifier_settings == nullptr) {
    return nullptr;
  }
  auto result = td::make_unique<BotVerifierSettings>(std::move(bot_verifier_settings));
  if (!result->is_valid()) {
    LOG(ERROR) << "Receive invalid " << *result;
    return nullptr;
  }
  return result;
}

td_api::object_ptr<td_api::botVerificationParameters> BotVerifierSettings::get_bot_verification_parameters_object(
    Td *td) const {
  if (!is_valid()) {
    return nullptr;
  }
  td_api::object_ptr<td_api::formattedText> description;
  if (!description_.empty() || can_modify_custom_description_) {
    FormattedText text;
    text.text = description_;
    text.entities = find_entities(text.text, true, true);
    description = get_formatted_text_object(td->user_manager_.get(), text, true, -1);
  }
  return td_api::make_object<td_api::botVerificationParameters>(icon_.get(), company_, std::move(description),
                                                                can_modify_custom_description_);
}

bool operator==(const BotVerifierSettings &lhs, const BotVerifierSettings &rhs) {
  return lhs.icon_ == rhs.icon_ && lhs.company_ == rhs.company_ && lhs.description_ == rhs.description_ &&
         lhs.can_modify_custom_description_ == rhs.can_modify_custom_description_;
}

StringBuilder &operator<<(StringBuilder &string_builder, const BotVerifierSettings &bot_verifier_settings) {
  return string_builder << "VerificationSettings[" << bot_verifier_settings.icon_ << " by "
                        << bot_verifier_settings.company_ << ']';
}

}  // namespace td
