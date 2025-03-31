//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/StickerPhotoSize.h"

#include "td/telegram/StickersManager.h"
#include "td/telegram/Td.h"

#include "td/utils/logging.h"

namespace td {

Result<unique_ptr<StickerPhotoSize>> StickerPhotoSize::get_sticker_photo_size(
    Td *td, const td_api::object_ptr<td_api::chatPhotoSticker> &sticker) {
  if (sticker == nullptr) {
    return Status::Error(400, "Sticker must not be null");
  }
  if (sticker->type_ == nullptr) {
    return Status::Error(400, "Type must be non-null");
  }
  if (sticker->background_fill_ == nullptr) {
    return Status::Error(400, "Background must be non-null");
  }
  auto result = make_unique<StickerPhotoSize>();
  switch (sticker->type_->get_id()) {
    case td_api::chatPhotoStickerTypeRegularOrMask::ID: {
      auto type = static_cast<const td_api::chatPhotoStickerTypeRegularOrMask *>(sticker->type_.get());
      result->type_ = Type::Sticker;
      result->sticker_set_id_ = StickerSetId(type->sticker_set_id_);
      result->sticker_id_ = type->sticker_id_;
      if (!td->stickers_manager_->have_sticker(result->sticker_set_id_, result->sticker_id_)) {
        return Status::Error(400, "Sticker not found");
      }
      break;
    }
    case td_api::chatPhotoStickerTypeCustomEmoji::ID: {
      auto type = static_cast<const td_api::chatPhotoStickerTypeCustomEmoji *>(sticker->type_.get());
      result->type_ = Type::CustomEmoji;
      result->custom_emoji_id_ = CustomEmojiId(type->custom_emoji_id_);
      if (!td->stickers_manager_->have_custom_emoji(result->custom_emoji_id_)) {
        return Status::Error(400, "Custom emoji not found");
      }
      break;
    }
  }
  auto fill = sticker->background_fill_.get();
  switch (fill->get_id()) {
    case td_api::backgroundFillSolid::ID: {
      auto solid = static_cast<const td_api::backgroundFillSolid *>(fill);
      result->background_colors_.push_back(solid->color_);
      break;
    }
    case td_api::backgroundFillGradient::ID: {
      auto gradient = static_cast<const td_api::backgroundFillGradient *>(fill);
      result->background_colors_.push_back(gradient->top_color_);
      result->background_colors_.push_back(gradient->bottom_color_);
      break;
    }
    case td_api::backgroundFillFreeformGradient::ID: {
      auto freeform = static_cast<const td_api::backgroundFillFreeformGradient *>(fill);
      if (freeform->colors_.size() != 3 && freeform->colors_.size() != 4) {
        return Status::Error(400, "Invalid number of colors specified");
      }
      result->background_colors_ = freeform->colors_;
      break;
    }
    default:
      UNREACHABLE();
      break;
  }
  for (auto &color : result->background_colors_) {
    color &= 0xFFFFFF;
  }
  return std::move(result);
}

telegram_api::object_ptr<telegram_api::VideoSize> StickerPhotoSize::get_input_video_size_object(Td *td) const {
  switch (type_) {
    case Type::Sticker:
      return telegram_api::make_object<telegram_api::videoSizeStickerMarkup>(
          td->stickers_manager_->get_input_sticker_set(sticker_set_id_), sticker_id_,
          vector<int32>(background_colors_));
    case Type::CustomEmoji:
      return telegram_api::make_object<telegram_api::videoSizeEmojiMarkup>(custom_emoji_id_.get(),
                                                                           vector<int32>(background_colors_));
    default:
      UNREACHABLE();
      return nullptr;
  }
}

unique_ptr<StickerPhotoSize> StickerPhotoSize::get_sticker_photo_size(
    Td *td, telegram_api::object_ptr<telegram_api::VideoSize> &&size_ptr) {
  CHECK(size_ptr != nullptr);
  auto result = make_unique<StickerPhotoSize>();
  bool is_valid = false;
  switch (size_ptr->get_id()) {
    case telegram_api::videoSizeEmojiMarkup::ID: {
      auto size = move_tl_object_as<telegram_api::videoSizeEmojiMarkup>(size_ptr);
      result->type_ = Type::CustomEmoji;
      result->custom_emoji_id_ = CustomEmojiId(size->emoji_id_);
      result->background_colors_ = std::move(size->background_colors_);
      is_valid = result->custom_emoji_id_.is_valid();
      break;
    }
    case telegram_api::videoSizeStickerMarkup::ID: {
      auto size = move_tl_object_as<telegram_api::videoSizeStickerMarkup>(size_ptr);
      result->type_ = Type::Sticker;
      result->sticker_set_id_ = td->stickers_manager_->add_sticker_set(std::move(size->stickerset_));
      result->sticker_id_ = size->sticker_id_;
      result->background_colors_ = std::move(size->background_colors_);
      is_valid = result->sticker_set_id_.is_valid() && result->sticker_id_ != 0;
      break;
    }
    default:
      UNREACHABLE();
  }
  if (!is_valid || result->background_colors_.empty() || result->background_colors_.size() > 4) {
    LOG(ERROR) << "Receive invalid " << *result;
    return {};
  }
  for (auto &color : result->background_colors_) {
    color &= 0xFFFFFF;
  }
  return result;
}

td_api::object_ptr<td_api::chatPhotoSticker> StickerPhotoSize::get_chat_photo_sticker_object() const {
  td_api::object_ptr<td_api::ChatPhotoStickerType> sticker_type;
  switch (type_) {
    case Type::Sticker:
      sticker_type = td_api::make_object<td_api::chatPhotoStickerTypeRegularOrMask>(sticker_set_id_.get(), sticker_id_);
      break;
    case Type::CustomEmoji:
      sticker_type = td_api::make_object<td_api::chatPhotoStickerTypeCustomEmoji>(custom_emoji_id_.get());
      break;
    default:
      UNREACHABLE();
      return nullptr;
  }
  CHECK(sticker_type != nullptr);

  auto background_fill = [&](vector<int32> colors) -> td_api::object_ptr<td_api::BackgroundFill> {
    switch (colors.size()) {
      case 1:
        return td_api::make_object<td_api::backgroundFillSolid>(colors[0]);
      case 2:
        return td_api::make_object<td_api::backgroundFillGradient>(colors[0], colors[1], 0);
      case 3:
      case 4:
        return td_api::make_object<td_api::backgroundFillFreeformGradient>(std::move(colors));
      default:
        UNREACHABLE();
        return nullptr;
    }
  }(background_colors_);

  return td_api::make_object<td_api::chatPhotoSticker>(std::move(sticker_type), std::move(background_fill));
}

bool operator==(const StickerPhotoSize &lhs, const StickerPhotoSize &rhs) {
  return lhs.type_ == rhs.type_ && lhs.sticker_set_id_ == rhs.sticker_set_id_ && lhs.sticker_id_ == rhs.sticker_id_ &&
         lhs.custom_emoji_id_ == rhs.custom_emoji_id_ && lhs.background_colors_ == rhs.background_colors_;
}

bool operator!=(const StickerPhotoSize &lhs, const StickerPhotoSize &rhs) {
  return !(lhs == rhs);
}

StringBuilder &operator<<(StringBuilder &string_builder, const StickerPhotoSize &sticker_photo_size) {
  switch (sticker_photo_size.type_) {
    case StickerPhotoSize::Type::Sticker:
      return string_builder << sticker_photo_size.sticker_id_ << " from " << sticker_photo_size.sticker_set_id_
                            << " on " << sticker_photo_size.background_colors_;
    case StickerPhotoSize::Type::CustomEmoji:
      return string_builder << sticker_photo_size.custom_emoji_id_ << " on " << sticker_photo_size.background_colors_;
    default:
      UNREACHABLE();
      return string_builder;
  }
}

}  // namespace td
