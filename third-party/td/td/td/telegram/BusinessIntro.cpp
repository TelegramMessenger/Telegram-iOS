//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/BusinessIntro.h"

#include "td/telegram/DialogId.h"
#include "td/telegram/Document.h"
#include "td/telegram/files/FileManager.h"
#include "td/telegram/files/FileType.h"
#include "td/telegram/misc.h"
#include "td/telegram/StickerFormat.h"
#include "td/telegram/StickersManager.h"
#include "td/telegram/StickerType.h"
#include "td/telegram/Td.h"

namespace td {

BusinessIntro::BusinessIntro(Td *td, telegram_api::object_ptr<telegram_api::businessIntro> intro) {
  if (intro == nullptr) {
    return;
  }
  if (!clean_input_string(intro->title_)) {
    intro->title_.clear();
  }
  if (!clean_input_string(intro->description_)) {
    intro->description_.clear();
  }
  title_ = std::move(intro->title_);
  description_ = std::move(intro->description_);
  sticker_file_id_ = td->stickers_manager_
                         ->on_get_sticker_document(std::move(intro->sticker_), StickerFormat::Unknown, "BusinessIntro")
                         .second;
}

BusinessIntro::BusinessIntro(Td *td, td_api::object_ptr<td_api::inputBusinessStartPage> intro) {
  if (intro == nullptr) {
    return;
  }
  title_ = std::move(intro->title_);
  description_ = std::move(intro->message_);
  auto r_file_id = td->file_manager_->get_input_file_id(FileType::Sticker, intro->sticker_, DialogId(), true, false);
  auto file_id = r_file_id.is_ok() ? r_file_id.move_as_ok() : FileId();
  if (file_id.is_valid()) {
    auto file_view = td->file_manager_->get_file_view(file_id);
    const auto *main_remote_location = file_view.get_main_remote_location();
    if (main_remote_location == nullptr || !main_remote_location->is_document() || main_remote_location->is_web() ||
        td->stickers_manager_->get_sticker_type(file_id) == StickerType::CustomEmoji) {
      file_id = FileId();
    }
  }
  sticker_file_id_ = file_id;
}

td_api::object_ptr<td_api::businessStartPage> BusinessIntro::get_business_start_page_object(Td *td) const {
  if (is_empty()) {
    return nullptr;
  }
  return td_api::make_object<td_api::businessStartPage>(title_, description_,
                                                        td->stickers_manager_->get_sticker_object(sticker_file_id_));
}

telegram_api::object_ptr<telegram_api::inputBusinessIntro> BusinessIntro::get_input_business_intro(Td *td) const {
  int32 flags = 0;
  telegram_api::object_ptr<telegram_api::InputDocument> input_document;
  if (sticker_file_id_.is_valid()) {
    auto file_view = td->file_manager_->get_file_view(sticker_file_id_);
    const auto *main_remote_location = file_view.get_main_remote_location();
    CHECK(main_remote_location != nullptr);
    input_document = main_remote_location->as_input_document();
    flags |= telegram_api::inputBusinessIntro::STICKER_MASK;
  }

  return telegram_api::make_object<telegram_api::inputBusinessIntro>(flags, title_, description_,
                                                                     std::move(input_document));
}

vector<FileId> BusinessIntro::get_file_ids(const Td *td) const {
  if (!sticker_file_id_.is_valid()) {
    return {};
  }
  return Document(Document::Type::Sticker, sticker_file_id_).get_file_ids(td);
}

bool operator==(const BusinessIntro &lhs, const BusinessIntro &rhs) {
  return lhs.title_ == rhs.title_ && lhs.description_ == rhs.description_ &&
         lhs.sticker_file_id_ == rhs.sticker_file_id_;
}

StringBuilder &operator<<(StringBuilder &string_builder, const BusinessIntro &intro) {
  return string_builder << "business intro " << intro.title_ << '|' << intro.description_ << '|'
                        << intro.sticker_file_id_;
}

}  // namespace td
