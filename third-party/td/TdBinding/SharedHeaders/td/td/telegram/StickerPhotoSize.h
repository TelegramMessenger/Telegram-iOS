//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/CustomEmojiId.h"
#include "td/telegram/StickerSetId.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"

#include "td/utils/common.h"
#include "td/utils/Status.h"
#include "td/utils/StringBuilder.h"

namespace td {

class Td;

class StickerPhotoSize {
  enum class Type : int32 { Sticker, CustomEmoji };
  Type type_ = Type::CustomEmoji;
  CustomEmojiId custom_emoji_id_;
  StickerSetId sticker_set_id_;
  int64 sticker_id_ = 0;
  vector<int32> background_colors_;

  friend bool operator==(const StickerPhotoSize &lhs, const StickerPhotoSize &rhs);

  friend StringBuilder &operator<<(StringBuilder &string_builder, const StickerPhotoSize &sticker_photo_size);

 public:
  static Result<unique_ptr<StickerPhotoSize>> get_sticker_photo_size(
      Td *td, const td_api::object_ptr<td_api::chatPhotoSticker> &chat_photo_sticker);

  static unique_ptr<StickerPhotoSize> get_sticker_photo_size(
      Td *td, telegram_api::object_ptr<telegram_api::VideoSize> &&size_ptr);

  telegram_api::object_ptr<telegram_api::VideoSize> get_input_video_size_object(Td *td) const;

  td_api::object_ptr<td_api::chatPhotoSticker> get_chat_photo_sticker_object() const;

  template <class StorerT>
  void store(StorerT &storer) const;

  template <class ParserT>
  void parse(ParserT &parser);
};

bool operator==(const StickerPhotoSize &lhs, const StickerPhotoSize &rhs);
bool operator!=(const StickerPhotoSize &lhs, const StickerPhotoSize &rhs);

StringBuilder &operator<<(StringBuilder &string_builder, const StickerPhotoSize &sticker_photo_size);

}  // namespace td
