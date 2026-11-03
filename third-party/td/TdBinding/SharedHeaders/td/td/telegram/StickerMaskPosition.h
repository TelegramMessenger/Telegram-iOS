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
#include "td/utils/StringBuilder.h"

namespace td {

class StickerMaskPosition {
  int32 point_ = -1;
  double x_shift_ = 0;
  double y_shift_ = 0;
  double scale_ = 0;

  friend bool operator==(const StickerMaskPosition &lhs, const StickerMaskPosition &rhs);

  friend StringBuilder &operator<<(StringBuilder &string_builder, const StickerMaskPosition &sticker_mask_position);

 public:
  StickerMaskPosition() = default;

  explicit StickerMaskPosition(const td_api::object_ptr<td_api::maskPosition> &mask_position);

  explicit StickerMaskPosition(const telegram_api::object_ptr<telegram_api::maskCoords> &mask_coords);

  telegram_api::object_ptr<telegram_api::maskCoords> get_input_mask_coords() const;

  td_api::object_ptr<td_api::maskPosition> get_mask_position_object() const;

  template <class StorerT>
  void store(StorerT &storer) const;

  template <class ParserT>
  void parse(ParserT &parser);
};

bool operator==(const StickerMaskPosition &lhs, const StickerMaskPosition &rhs);
bool operator!=(const StickerMaskPosition &lhs, const StickerMaskPosition &rhs);

StringBuilder &operator<<(StringBuilder &string_builder, const StickerMaskPosition &sticker_mask_position);

}  // namespace td
