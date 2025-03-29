//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/StickerListType.h"

namespace td {

string get_sticker_list_type_database_key(StickerListType sticker_list_type) {
  switch (sticker_list_type) {
    case StickerListType::DialogPhoto:
      return "default_dialog_photo_custom_emoji_ids";
    case StickerListType::UserProfilePhoto:
      return "default_profile_photo_custom_emoji_ids";
    case StickerListType::Background:
      return "default_background_custom_emoji_ids";
    case StickerListType::DisallowedChannelEmojiStatus:
      return "disallowed_channel_emoji_status_custom_emoji_ids";
    default:
      UNREACHABLE();
      return string();
  }
}

StringBuilder &operator<<(StringBuilder &string_builder, StickerListType sticker_list_type) {
  switch (sticker_list_type) {
    case StickerListType::DialogPhoto:
      return string_builder << "default chat photo custom emoji identifiers";
    case StickerListType::UserProfilePhoto:
      return string_builder << "default user profile photo custom emoji identifiers";
    case StickerListType::Background:
      return string_builder << "default background custom emoji identifiers";
    case StickerListType::DisallowedChannelEmojiStatus:
      return string_builder << "disallowed chat emoji status custom emoji identifiers";
    default:
      UNREACHABLE();
      return string_builder;
  }
}

}  // namespace td
