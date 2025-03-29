//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/EmojiGroupType.h"

namespace td {

EmojiGroupType get_emoji_group_type(const td_api::object_ptr<td_api::EmojiCategoryType> &type) {
  if (type == nullptr) {
    return EmojiGroupType::Default;
  }
  switch (type->get_id()) {
    case td_api::emojiCategoryTypeDefault::ID:
      return EmojiGroupType::Default;
    case td_api::emojiCategoryTypeEmojiStatus::ID:
      return EmojiGroupType::EmojiStatus;
    case td_api::emojiCategoryTypeChatPhoto::ID:
      return EmojiGroupType::ProfilePhoto;
    case td_api::emojiCategoryTypeRegularStickers::ID:
      return EmojiGroupType::RegularStickers;
    default:
      UNREACHABLE();
      return EmojiGroupType::Default;
  }
}

StringBuilder &operator<<(StringBuilder &string_builder, EmojiGroupType emoji_group_type) {
  switch (emoji_group_type) {
    case EmojiGroupType::Default:
      return string_builder << "Default";
    case EmojiGroupType::EmojiStatus:
      return string_builder << "EmojiStatus";
    case EmojiGroupType::ProfilePhoto:
      return string_builder << "ChatPhoto";
    case EmojiGroupType::RegularStickers:
      return string_builder << "RegularStickers";
    default:
      UNREACHABLE();
      return string_builder;
  }
}

}  // namespace td
