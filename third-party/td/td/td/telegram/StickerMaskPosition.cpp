//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/StickerMaskPosition.h"

namespace td {

static td_api::object_ptr<td_api::MaskPoint> get_mask_point_object(int32 point) {
  switch (point) {
    case 0:
      return td_api::make_object<td_api::maskPointForehead>();
    case 1:
      return td_api::make_object<td_api::maskPointEyes>();
    case 2:
      return td_api::make_object<td_api::maskPointMouth>();
    case 3:
      return td_api::make_object<td_api::maskPointChin>();
    default:
      UNREACHABLE();
      return nullptr;
  }
}

StickerMaskPosition::StickerMaskPosition(const telegram_api::object_ptr<telegram_api::maskCoords> &mask_coords) {
  if (mask_coords == nullptr) {
    return;
  }
  int32 point = mask_coords->n_;
  if (point < 0 || point > 3) {
    return;
  }
  point_ = mask_coords->n_;
  x_shift_ = mask_coords->x_;
  y_shift_ = mask_coords->y_;
  scale_ = mask_coords->zoom_;
}

StickerMaskPosition::StickerMaskPosition(const td_api::object_ptr<td_api::maskPosition> &mask_position) {
  if (mask_position == nullptr || mask_position->point_ == nullptr) {
    return;
  }
  point_ = [mask_point_id = mask_position->point_->get_id()] {
    switch (mask_point_id) {
      case td_api::maskPointForehead::ID:
        return 0;
      case td_api::maskPointEyes::ID:
        return 1;
      case td_api::maskPointMouth::ID:
        return 2;
      case td_api::maskPointChin::ID:
        return 3;
      default:
        UNREACHABLE();
        return -1;
    }
  }();
  x_shift_ = mask_position->x_shift_;
  y_shift_ = mask_position->y_shift_;
  scale_ = mask_position->scale_;
}

telegram_api::object_ptr<telegram_api::maskCoords> StickerMaskPosition::get_input_mask_coords() const {
  if (point_ < 0) {
    return nullptr;
  }
  return telegram_api::make_object<telegram_api::maskCoords>(point_, x_shift_, y_shift_, scale_);
}

td_api::object_ptr<td_api::maskPosition> StickerMaskPosition::get_mask_position_object() const {
  if (point_ < 0) {
    return nullptr;
  }
  return td_api::make_object<td_api::maskPosition>(get_mask_point_object(point_), x_shift_, y_shift_, scale_);
}

bool operator==(const StickerMaskPosition &lhs, const StickerMaskPosition &rhs) {
  return lhs.point_ == rhs.point_ && lhs.x_shift_ == rhs.x_shift_ && lhs.y_shift_ == rhs.y_shift_ &&
         lhs.scale_ == rhs.scale_;
}

bool operator!=(const StickerMaskPosition &lhs, const StickerMaskPosition &rhs) {
  return !(lhs == rhs);
}

StringBuilder &operator<<(StringBuilder &string_builder, const StickerMaskPosition &sticker_mask_position) {
  if (sticker_mask_position.point_ < 0) {
    return string_builder << "MaskPosition[]";
  }
  return string_builder << "MaskPosition[" << sticker_mask_position.point_ << ' ' << sticker_mask_position.x_shift_
                        << ' ' << sticker_mask_position.y_shift_ << ' ' << sticker_mask_position.scale_;
}

}  // namespace td
