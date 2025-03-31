//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/StickerPhotoSize.h"

#include "td/utils/tl_helpers.h"

namespace td {

template <class StorerT>
void StickerPhotoSize::store(StorerT &storer) const {
  bool is_custom_emoji = type_ == Type::CustomEmoji;
  bool is_sticker = type_ == Type::Sticker;
  BEGIN_STORE_FLAGS();
  STORE_FLAG(is_custom_emoji);
  STORE_FLAG(is_sticker);
  END_STORE_FLAGS();
  if (is_custom_emoji) {
    td::store(custom_emoji_id_, storer);
  } else if (is_sticker) {
    td::store(sticker_set_id_, storer);
    td::store(sticker_id_, storer);
  }
  td::store(background_colors_, storer);
}

template <class ParserT>
void StickerPhotoSize::parse(ParserT &parser) {
  bool is_custom_emoji;
  bool is_sticker;
  BEGIN_PARSE_FLAGS();
  PARSE_FLAG(is_custom_emoji);
  PARSE_FLAG(is_sticker);
  END_PARSE_FLAGS();
  if (is_custom_emoji) {
    type_ = Type::CustomEmoji;
    td::parse(custom_emoji_id_, parser);
  } else if (is_sticker) {
    type_ = Type::Sticker;
    td::parse(sticker_set_id_, parser);
    td::parse(sticker_id_, parser);
  } else {
    UNREACHABLE();
  }
  td::parse(background_colors_, parser);
}

}  // namespace td
