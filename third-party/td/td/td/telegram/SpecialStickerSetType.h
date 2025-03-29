//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/telegram_api.h"

#include "td/utils/common.h"
#include "td/utils/HashTableUtils.h"

namespace td {

class SpecialStickerSetType {
  explicit SpecialStickerSetType(string type) : type_(type) {
  }

  friend struct SpecialStickerSetTypeHash;

 public:
  string type_;

  static SpecialStickerSetType animated_emoji();

  static SpecialStickerSetType animated_emoji_click();

  static SpecialStickerSetType animated_dice(const string &emoji);

  static SpecialStickerSetType premium_gifts();

  static SpecialStickerSetType generic_animations();

  static SpecialStickerSetType default_statuses();

  static SpecialStickerSetType default_channel_statuses();

  static SpecialStickerSetType default_topic_icons();

  string get_dice_emoji() const;

  bool is_empty() const {
    return type_.empty();
  }

  SpecialStickerSetType() = default;

  explicit SpecialStickerSetType(const telegram_api::object_ptr<telegram_api::InputStickerSet> &input_sticker_set);

  telegram_api::object_ptr<telegram_api::InputStickerSet> get_input_sticker_set() const;
};

inline bool operator==(const SpecialStickerSetType &lhs, const SpecialStickerSetType &rhs) {
  return lhs.type_ == rhs.type_;
}

inline bool operator!=(const SpecialStickerSetType &lhs, const SpecialStickerSetType &rhs) {
  return !(lhs == rhs);
}

struct SpecialStickerSetTypeHash {
  uint32 operator()(SpecialStickerSetType type) const {
    return Hash<string>()(type.type_);
  }
};

}  // namespace td
