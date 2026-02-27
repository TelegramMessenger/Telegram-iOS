//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"

#include "td/utils/common.h"
#include "td/utils/HashTableUtils.h"
#include "td/utils/Status.h"
#include "td/utils/StringBuilder.h"

namespace td {

class StarGiftAttributeId {
  enum class Type : int32 { None, Model, Pattern, Backdrop };
  Type type_ = Type::None;
  int64 sticker_id_ = 0;
  int32 backdrop_id_ = 0;

  StarGiftAttributeId(Type type, int64 sticker_id, int32 backdrop_id);

  static Result<StarGiftAttributeId> get_star_gift_attribute_id(
      const td_api::object_ptr<td_api::UpgradedGiftAttributeId> &attribute);

  telegram_api::object_ptr<telegram_api::StarGiftAttributeId> get_input_star_gift_attribute_id_object() const;

  friend struct StarGiftAttributeIdHash;

  friend bool operator==(const StarGiftAttributeId &lhs, const StarGiftAttributeId &rhs);

  friend StringBuilder &operator<<(StringBuilder &string_builder, const StarGiftAttributeId &attribute_id);

 public:
  StarGiftAttributeId() = default;

  explicit StarGiftAttributeId(telegram_api::object_ptr<telegram_api::StarGiftAttributeId> attribute);

  static StarGiftAttributeId model(int64 sticker_id);

  static StarGiftAttributeId pattern(int64 sticker_id);

  static StarGiftAttributeId backdrop(int32 backdrop_id);

  static Result<vector<StarGiftAttributeId>> get_star_gift_attribute_ids(
      const vector<td_api::object_ptr<td_api::UpgradedGiftAttributeId>> &attributes);

  static vector<telegram_api::object_ptr<telegram_api::StarGiftAttributeId>> get_input_star_gift_attribute_ids_object(
      const vector<StarGiftAttributeId> &attributes);
};

struct StarGiftAttributeIdHash {
  uint32 operator()(StarGiftAttributeId star_gift_attribute_id) const {
    return star_gift_attribute_id.backdrop_id_ ? Hash<int32>()(star_gift_attribute_id.backdrop_id_)
                                               : Hash<int64>()(star_gift_attribute_id.sticker_id_);
  }
};

bool operator==(const StarGiftAttributeId &lhs, const StarGiftAttributeId &rhs);

inline bool operator!=(const StarGiftAttributeId &lhs, const StarGiftAttributeId &rhs) {
  return !(lhs == rhs);
}

StringBuilder &operator<<(StringBuilder &string_builder, const StarGiftAttributeId &attribute_id);

}  // namespace td
