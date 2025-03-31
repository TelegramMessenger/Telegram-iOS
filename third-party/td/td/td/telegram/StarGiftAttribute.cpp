//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/StarGiftAttribute.h"

#include "td/telegram/Dependencies.h"
#include "td/telegram/MessageSender.h"
#include "td/telegram/StickerFormat.h"
#include "td/telegram/StickersManager.h"
#include "td/telegram/Td.h"

namespace td {

StarGiftAttributeSticker::StarGiftAttributeSticker(
    Td *td, telegram_api::object_ptr<telegram_api::starGiftAttributeModel> &&attribute)
    : name_(std::move(attribute->name_))
    , sticker_file_id_(td->stickers_manager_
                           ->on_get_sticker_document(std::move(attribute->document_), StickerFormat::Unknown,
                                                     "StarGiftAttributeSticker")
                           .second)
    , rarity_permille_(attribute->rarity_permille_) {
}

StarGiftAttributeSticker::StarGiftAttributeSticker(
    Td *td, telegram_api::object_ptr<telegram_api::starGiftAttributePattern> &&attribute)
    : name_(std::move(attribute->name_))
    , sticker_file_id_(td->stickers_manager_
                           ->on_get_sticker_document(std::move(attribute->document_), StickerFormat::Unknown,
                                                     "StarGiftAttributeSticker")
                           .second)
    , rarity_permille_(attribute->rarity_permille_) {
}

td_api::object_ptr<td_api::upgradedGiftModel> StarGiftAttributeSticker::get_upgraded_gift_model_object(
    const Td *td) const {
  CHECK(is_valid());
  return td_api::make_object<td_api::upgradedGiftModel>(
      name_, td->stickers_manager_->get_sticker_object(sticker_file_id_), rarity_permille_);
}

td_api::object_ptr<td_api::upgradedGiftSymbol> StarGiftAttributeSticker::get_upgraded_gift_symbol_object(
    const Td *td) const {
  CHECK(is_valid());
  return td_api::make_object<td_api::upgradedGiftSymbol>(
      name_, td->stickers_manager_->get_sticker_object(sticker_file_id_), rarity_permille_);
}

bool operator==(const StarGiftAttributeSticker &lhs, const StarGiftAttributeSticker &rhs) {
  return lhs.name_ == rhs.name_ && lhs.sticker_file_id_ == rhs.sticker_file_id_ &&
         lhs.rarity_permille_ == rhs.rarity_permille_;
}

StarGiftAttributeBackdrop::StarGiftAttributeBackdrop(
    telegram_api::object_ptr<telegram_api::starGiftAttributeBackdrop> &&attribute)
    : name_(std::move(attribute->name_))
    , center_color_(attribute->center_color_)
    , edge_color_(attribute->edge_color_)
    , pattern_color_(attribute->pattern_color_)
    , text_color_(attribute->text_color_)
    , rarity_permille_(attribute->rarity_permille_) {
}

td_api::object_ptr<td_api::upgradedGiftBackdrop> StarGiftAttributeBackdrop::get_upgraded_gift_backdrop_object() const {
  CHECK(is_valid());
  return td_api::make_object<td_api::upgradedGiftBackdrop>(
      name_,
      td_api::make_object<td_api::upgradedGiftBackdropColors>(center_color_, edge_color_, pattern_color_, text_color_),
      rarity_permille_);
}

bool operator==(const StarGiftAttributeBackdrop &lhs, const StarGiftAttributeBackdrop &rhs) {
  return lhs.name_ == rhs.name_ && lhs.center_color_ == rhs.center_color_ && lhs.edge_color_ == rhs.edge_color_ &&
         lhs.pattern_color_ == rhs.pattern_color_ && lhs.text_color_ == rhs.text_color_ &&
         lhs.rarity_permille_ == rhs.rarity_permille_;
}

StarGiftAttributeOriginalDetails::StarGiftAttributeOriginalDetails(
    Td *td, telegram_api::object_ptr<telegram_api::starGiftAttributeOriginalDetails> &&attribute)
    : receiver_dialog_id_(attribute->recipient_id_)
    , date_(attribute->date_)
    , message_(get_formatted_text(td->user_manager_.get(), std::move(attribute->message_), true, false,
                                  "starGiftAttributeBackdrop")) {
  if (attribute->sender_id_ != nullptr) {
    sender_dialog_id_ = DialogId(attribute->sender_id_);
  }
}

td_api::object_ptr<td_api::upgradedGiftOriginalDetails>
StarGiftAttributeOriginalDetails::get_upgraded_gift_original_details_object(Td *td) const {
  if (!is_valid()) {
    return nullptr;
  }
  return td_api::make_object<td_api::upgradedGiftOriginalDetails>(
      sender_dialog_id_ == DialogId()
          ? nullptr
          : get_message_sender_object(td, sender_dialog_id_, "upgradedGiftOriginalDetails sender"),
      get_message_sender_object(td, receiver_dialog_id_, "upgradedGiftOriginalDetails sender"),
      get_formatted_text_object(td->user_manager_.get(), message_, true, -1), date_);
}

void StarGiftAttributeOriginalDetails::add_dependencies(Dependencies &dependencies) const {
  dependencies.add_message_sender_dependencies(sender_dialog_id_);
  dependencies.add_message_sender_dependencies(receiver_dialog_id_);
}

bool operator==(const StarGiftAttributeOriginalDetails &lhs, const StarGiftAttributeOriginalDetails &rhs) {
  return lhs.sender_dialog_id_ == rhs.sender_dialog_id_ && lhs.receiver_dialog_id_ == rhs.receiver_dialog_id_ &&
         lhs.date_ == rhs.date_ && lhs.message_ == rhs.message_;
}

}  // namespace td
