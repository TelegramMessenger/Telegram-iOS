//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/SpecialStickerSetType.h"

#include "td/utils/misc.h"
#include "td/utils/Slice.h"
#include "td/utils/SliceBuilder.h"

namespace td {

SpecialStickerSetType SpecialStickerSetType::animated_emoji() {
  return SpecialStickerSetType("animated_emoji_sticker_set");
}

SpecialStickerSetType SpecialStickerSetType::animated_emoji_click() {
  return SpecialStickerSetType("animated_emoji_click_sticker_set");
}

SpecialStickerSetType SpecialStickerSetType::animated_dice(const string &emoji) {
  CHECK(!emoji.empty());
  return SpecialStickerSetType(PSTRING() << "animated_dice_sticker_set#" << emoji);
}

SpecialStickerSetType SpecialStickerSetType::premium_gifts() {
  return SpecialStickerSetType("premium_gifts_sticker_set");
}

SpecialStickerSetType SpecialStickerSetType::generic_animations() {
  return SpecialStickerSetType("generic_animations_sticker_set");
}

SpecialStickerSetType SpecialStickerSetType::default_statuses() {
  return SpecialStickerSetType("default_statuses_sticker_set");
}

SpecialStickerSetType SpecialStickerSetType::default_channel_statuses() {
  return SpecialStickerSetType("default_channel_statuses_sticker_set");
}

SpecialStickerSetType SpecialStickerSetType::default_topic_icons() {
  return SpecialStickerSetType("default_topic_icons_sticker_set");
}

SpecialStickerSetType::SpecialStickerSetType(
    const telegram_api::object_ptr<telegram_api::InputStickerSet> &input_sticker_set) {
  CHECK(input_sticker_set != nullptr);
  switch (input_sticker_set->get_id()) {
    case telegram_api::inputStickerSetAnimatedEmoji::ID:
      *this = animated_emoji();
      break;
    case telegram_api::inputStickerSetAnimatedEmojiAnimations::ID:
      *this = animated_emoji_click();
      break;
    case telegram_api::inputStickerSetDice::ID:
      *this = animated_dice(static_cast<const telegram_api::inputStickerSetDice *>(input_sticker_set.get())->emoticon_);
      break;
    case telegram_api::inputStickerSetPremiumGifts::ID:
      *this = premium_gifts();
      break;
    case telegram_api::inputStickerSetEmojiGenericAnimations::ID:
      *this = generic_animations();
      break;
    case telegram_api::inputStickerSetEmojiDefaultStatuses::ID:
      *this = default_statuses();
      break;
    case telegram_api::inputStickerSetEmojiChannelDefaultStatuses::ID:
      *this = default_channel_statuses();
      break;
    case telegram_api::inputStickerSetEmojiDefaultTopicIcons::ID:
      *this = default_topic_icons();
      break;
    default:
      UNREACHABLE();
      break;
  }
}

string SpecialStickerSetType::get_dice_emoji() const {
  auto prefix = Slice("animated_dice_sticker_set#");
  if (begins_with(type_, prefix)) {
    return type_.substr(prefix.size());
  }
  return string();
}

telegram_api::object_ptr<telegram_api::InputStickerSet> SpecialStickerSetType::get_input_sticker_set() const {
  if (*this == animated_emoji()) {
    return telegram_api::make_object<telegram_api::inputStickerSetAnimatedEmoji>();
  }
  if (*this == animated_emoji_click()) {
    return telegram_api::make_object<telegram_api::inputStickerSetAnimatedEmojiAnimations>();
  }
  if (*this == premium_gifts()) {
    return telegram_api::make_object<telegram_api::inputStickerSetPremiumGifts>();
  }
  if (*this == generic_animations()) {
    return telegram_api::make_object<telegram_api::inputStickerSetEmojiGenericAnimations>();
  }
  if (*this == default_statuses()) {
    return telegram_api::make_object<telegram_api::inputStickerSetEmojiDefaultStatuses>();
  }
  if (*this == default_channel_statuses()) {
    return telegram_api::make_object<telegram_api::inputStickerSetEmojiChannelDefaultStatuses>();
  }
  if (*this == default_topic_icons()) {
    return telegram_api::make_object<telegram_api::inputStickerSetEmojiDefaultTopicIcons>();
  }
  auto emoji = get_dice_emoji();
  if (!emoji.empty()) {
    return telegram_api::make_object<telegram_api::inputStickerSetDice>(emoji);
  }

  UNREACHABLE();
  return nullptr;
}

}  // namespace td
