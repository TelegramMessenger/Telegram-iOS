//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/WebApp.h"

#include "td/telegram/AnimationsManager.h"
#include "td/telegram/Document.h"
#include "td/telegram/DocumentsManager.h"
#include "td/telegram/Photo.h"
#include "td/telegram/Td.h"
#include "td/telegram/telegram_api.h"

#include "td/utils/common.h"
#include "td/utils/logging.h"

namespace td {

WebApp::WebApp(Td *td, telegram_api::object_ptr<telegram_api::botApp> &&web_app, DialogId owner_dialog_id)
    : id_(web_app->id_)
    , access_hash_(web_app->access_hash_)
    , short_name_(std::move(web_app->short_name_))
    , title_(std::move(web_app->title_))
    , description_(std::move(web_app->description_))
    , hash_(web_app->hash_) {
  CHECK(td != nullptr);
  photo_ = get_photo(td, std::move(web_app->photo_), owner_dialog_id);
  if (photo_.is_empty()) {
    LOG(ERROR) << "Receive empty photo for Web App " << short_name_ << '/' << title_;
    photo_.id = 0;  // to prevent null photo in td_api
  }
  if (web_app->document_ != nullptr) {
    int32 document_id = web_app->document_->get_id();
    if (document_id == telegram_api::document::ID) {
      auto parsed_document = td->documents_manager_->on_get_document(
          move_tl_object_as<telegram_api::document>(web_app->document_), owner_dialog_id, false);
      if (parsed_document.type == Document::Type::Animation) {
        animation_file_id_ = parsed_document.file_id;
      } else {
        LOG(ERROR) << "Receive non-animation document for Web App " << short_name_ << '/' << title_;
      }
    }
  }
}

bool WebApp::is_empty() const {
  return short_name_.empty();
}

vector<FileId> WebApp::get_file_ids(const Td *td) const {
  auto result = photo_get_file_ids(photo_);
  Document(Document::Type::Animation, animation_file_id_).append_file_ids(td, result);
  return result;
}

td_api::object_ptr<td_api::webApp> WebApp::get_web_app_object(Td *td) const {
  return td_api::make_object<td_api::webApp>(short_name_, title_, description_,
                                             get_photo_object(td->file_manager_.get(), photo_),
                                             td->animations_manager_->get_animation_object(animation_file_id_));
}

bool operator==(const WebApp &lhs, const WebApp &rhs) {
  return lhs.id_ == rhs.id_ && lhs.access_hash_ == rhs.access_hash_ && lhs.short_name_ == rhs.short_name_ &&
         lhs.title_ == rhs.title_ && lhs.description_ == rhs.description_ && lhs.photo_ == rhs.photo_ &&
         lhs.animation_file_id_ == rhs.animation_file_id_ && lhs.hash_ == rhs.hash_;
}

bool operator!=(const WebApp &lhs, const WebApp &rhs) {
  return !(lhs == rhs);
}

StringBuilder &operator<<(StringBuilder &string_builder, const WebApp &web_app) {
  return string_builder << "WebApp[ID = " << web_app.id_ << ", access_hash = " << web_app.access_hash_
                        << ", short_name = " << web_app.short_name_ << ", title = " << web_app.title_
                        << ", description = " << web_app.description_ << ", photo = " << web_app.photo_
                        << ", animation_file_id = " << web_app.animation_file_id_ << "]";
}

}  // namespace td
