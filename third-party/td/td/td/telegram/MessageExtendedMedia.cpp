//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#include "td/telegram/MessageExtendedMedia.h"

#include "td/telegram/Dimensions.h"
#include "td/telegram/Document.h"
#include "td/telegram/DocumentsManager.h"
#include "td/telegram/files/FileManager.h"
#include "td/telegram/files/FileType.h"
#include "td/telegram/MessageContent.h"
#include "td/telegram/Photo.h"
#include "td/telegram/PhotoSize.h"
#include "td/telegram/StickersManager.h"
#include "td/telegram/Td.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/VideosManager.h"

#include "td/utils/algorithm.h"
#include "td/utils/logging.h"
#include "td/utils/MimeType.h"
#include "td/utils/PathView.h"

namespace td {

MessageExtendedMedia::MessageExtendedMedia(
    Td *td, telegram_api::object_ptr<telegram_api::MessageExtendedMedia> &&extended_media, DialogId owner_dialog_id) {
  if (extended_media == nullptr) {
    return;
  }

  switch (extended_media->get_id()) {
    case telegram_api::messageExtendedMediaPreview::ID: {
      auto media = move_tl_object_as<telegram_api::messageExtendedMediaPreview>(extended_media);
      type_ = Type::Preview;
      duration_ = media->video_duration_;
      dimensions_ = get_dimensions(media->w_, media->h_, "MessageExtendedMedia");
      if (media->thumb_ != nullptr) {
        if (media->thumb_->get_id() == telegram_api::photoStrippedSize::ID) {
          auto thumbnail = move_tl_object_as<telegram_api::photoStrippedSize>(media->thumb_);
          minithumbnail_ = thumbnail->bytes_.as_slice().str();
        } else {
          LOG(ERROR) << "Receive " << to_string(media->thumb_);
        }
      }
      break;
    }
    case telegram_api::messageExtendedMedia::ID: {
      auto media = move_tl_object_as<telegram_api::messageExtendedMedia>(extended_media);
      init_from_media(td, std::move(media->media_), owner_dialog_id);
      break;
    }
    default:
      UNREACHABLE();
  }
}

MessageExtendedMedia::MessageExtendedMedia(Td *td, telegram_api::object_ptr<telegram_api::MessageMedia> &&media,
                                           DialogId owner_dialog_id) {
  init_from_media(td, std::move(media), owner_dialog_id);
}

void MessageExtendedMedia::init_from_media(Td *td, telegram_api::object_ptr<telegram_api::MessageMedia> &&media,
                                           DialogId owner_dialog_id) {
  type_ = Type::Unsupported;
  switch (media->get_id()) {
    case telegram_api::messageMediaPhoto::ID: {
      auto photo = telegram_api::move_object_as<telegram_api::messageMediaPhoto>(media);
      if (photo->photo_ == nullptr) {
        break;
      }

      photo_ = get_photo(td, std::move(photo->photo_), owner_dialog_id);
      if (photo_.is_empty()) {
        break;
      }
      type_ = Type::Photo;
      break;
    }
    case telegram_api::messageMediaDocument::ID: {
      auto document = telegram_api::move_object_as<telegram_api::messageMediaDocument>(media);
      if (document->document_ == nullptr) {
        break;
      }

      auto document_ptr = std::move(document->document_);
      int32 document_id = document_ptr->get_id();
      if (document_id == telegram_api::documentEmpty::ID) {
        break;
      }
      CHECK(document_id == telegram_api::document::ID);

      auto parsed_document = td->documents_manager_->on_get_document(
          telegram_api::move_object_as<telegram_api::document>(document_ptr), owner_dialog_id, false);
      if (parsed_document.empty() || parsed_document.type != Document::Type::Video) {
        break;
      }
      CHECK(parsed_document.file_id.is_valid());
      video_file_id_ = parsed_document.file_id;
      start_timestamp_ = document->video_timestamp_;
      type_ = Type::Video;

      if (document->video_cover_ != nullptr) {
        photo_ = get_photo(td, std::move(document->video_cover_), owner_dialog_id);
      }
      break;
    }
    default:
      break;
  }
  if (type_ == Type::Unsupported) {
    unsupported_version_ = CURRENT_VERSION;
  }
}

Result<MessageExtendedMedia> MessageExtendedMedia::get_message_extended_media(
    Td *td, td_api::object_ptr<td_api::inputPaidMedia> &&paid_media, DialogId owner_dialog_id) {
  if (paid_media == nullptr) {
    return MessageExtendedMedia();
  }
  if (!owner_dialog_id.is_valid()) {
    return Status::Error(400, "Extended media can't be added to the invoice");
  }
  if (paid_media->type_ == nullptr) {
    return Status::Error(400, "Paid media type must be non-empty");
  }

  MessageExtendedMedia result;

  auto file_type = FileType::None;
  switch (paid_media->type_->get_id()) {
    case td_api::inputPaidMediaTypePhoto::ID:
      file_type = FileType::Photo;
      result.type_ = Type::Photo;
      break;
    case td_api::inputPaidMediaTypeVideo::ID:
      file_type = FileType::Video;
      result.type_ = Type::Video;
      break;
    default:
      UNREACHABLE();
      break;
  }

  TRY_RESULT(file_id, td->file_manager_->get_input_file_id(file_type, std::move(paid_media->media_), owner_dialog_id,
                                                           false, false));
  CHECK(file_id.is_valid());

  auto sticker_file_ids = td->stickers_manager_->get_attached_sticker_file_ids(paid_media->added_sticker_file_ids_);
  auto thumbnail =
      get_input_thumbnail_photo_size(td->file_manager_.get(), paid_media->thumbnail_.get(), owner_dialog_id, false);

  switch (result.type_) {
    case Type::Photo: {
      TRY_RESULT(photo, create_photo(td->file_manager_.get(), file_id, std::move(thumbnail), paid_media->width_,
                                     paid_media->height_, std::move(sticker_file_ids)));
      result.photo_ = std::move(photo);
      break;
    }
    case Type::Video: {
      auto type = static_cast<td_api::inputPaidMediaTypeVideo *>(paid_media->type_.get());

      TRY_RESULT(cover_file_id, td->file_manager_->get_input_file_id(FileType::Photo, type->cover_, owner_dialog_id,
                                                                     true, false, false));
      Photo cover;
      if (cover_file_id.is_valid()) {
        TRY_RESULT_ASSIGN(cover, create_photo(td->file_manager_.get(), cover_file_id, PhotoSize(), paid_media->width_,
                                              paid_media->height_, vector<FileId>()));
      }

      FileView file_view = td->file_manager_->get_file_view(file_id);
      auto suggested_path = file_view.suggested_path();
      const PathView path_view(suggested_path);
      string file_name = path_view.file_name().str();
      string mime_type = MimeType::from_extension(path_view.extension());

      bool has_stickers = !sticker_file_ids.empty();
      td->videos_manager_->create_video(file_id, string(), std::move(thumbnail), AnimationSize(), has_stickers,
                                        std::move(sticker_file_ids), std::move(file_name), std::move(mime_type),
                                        type->duration_, type->duration_,
                                        get_dimensions(paid_media->width_, paid_media->height_, nullptr),
                                        type->supports_streaming_, false, 0, 0.0, string(), false);
      result.video_file_id_ = file_id;
      result.photo_ = std::move(cover);
      result.start_timestamp_ = max(0, type->start_timestamp_);
      break;
    }
    default:
      UNREACHABLE();
  }
  return result;
}

void MessageExtendedMedia::update_from(const MessageExtendedMedia &old_extended_media) {
  if (!is_media() && old_extended_media.is_media()) {
    *this = old_extended_media;
  }
}

bool MessageExtendedMedia::update_to(Td *td,
                                     telegram_api::object_ptr<telegram_api::MessageExtendedMedia> extended_media_ptr,
                                     DialogId owner_dialog_id) {
  MessageExtendedMedia new_extended_media(td, std::move(extended_media_ptr), owner_dialog_id);
  if (!new_extended_media.is_media() && is_media()) {
    return false;
  }
  if (*this != new_extended_media || is_equal_but_different(new_extended_media)) {
    *this = std::move(new_extended_media);
    return true;
  }
  return false;
}

td_api::object_ptr<td_api::PaidMedia> MessageExtendedMedia::get_paid_media_object(Td *td) const {
  if (type_ == Type::Empty) {
    return nullptr;
  }

  switch (type_) {
    case Type::Unsupported:
      return td_api::make_object<td_api::paidMediaUnsupported>();
    case Type::Preview:
      return td_api::make_object<td_api::paidMediaPreview>(dimensions_.width, dimensions_.height, duration_,
                                                           get_minithumbnail_object(minithumbnail_));
    case Type::Photo: {
      auto photo = get_photo_object(td->file_manager_.get(), photo_);
      CHECK(photo != nullptr);
      return td_api::make_object<td_api::paidMediaPhoto>(std::move(photo));
    }
    case Type::Video:
      return td_api::make_object<td_api::paidMediaVideo>(td->videos_manager_->get_video_object(video_file_id_),
                                                         get_photo_object(td->file_manager_.get(), photo_),
                                                         max(0, start_timestamp_));
    default:
      UNREACHABLE();
      return nullptr;
  }
}

void MessageExtendedMedia::append_file_ids(const Td *td, vector<FileId> &file_ids) const {
  switch (type_) {
    case Type::Empty:
    case Type::Unsupported:
    case Type::Preview:
      break;
    case Type::Photo:
      append(file_ids, photo_get_file_ids(photo_));
      break;
    case Type::Video:
      Document(Document::Type::Video, video_file_id_).append_file_ids(td, file_ids);
      if (!photo_.is_empty()) {
        append(file_ids, photo_get_file_ids(photo_));
      }
      break;
    default:
      UNREACHABLE();
      break;
  }
}

void MessageExtendedMedia::delete_thumbnail(Td *td) {
  switch (type_) {
    case Type::Empty:
    case Type::Unsupported:
    case Type::Preview:
      break;
    case Type::Photo:
      photo_delete_thumbnail(photo_);
      break;
    case Type::Video:
      td->videos_manager_->delete_video_thumbnail(video_file_id_);
      break;
    default:
      UNREACHABLE();
      break;
  }
}

unique_ptr<MessageContent> MessageExtendedMedia::get_message_content() const {
  switch (type_) {
    case Type::Photo:
      return create_photo_message_content(photo_);
    case Type::Video:
      return create_video_message_content(video_file_id_, photo_, start_timestamp_);
    case Type::Empty:
    case Type::Unsupported:
    case Type::Preview:
    default:
      UNREACHABLE();
      return nullptr;
  }
}

int32 MessageExtendedMedia::get_duration(const Td *td) const {
  if (!has_media_timestamp()) {
    return -1;
  }
  return td->videos_manager_->get_video_duration(video_file_id_);
}

FileId MessageExtendedMedia::get_any_file_id() const {
  switch (type_) {
    case Type::Empty:
    case Type::Unsupported:
    case Type::Preview:
      break;
    case Type::Photo:
      return get_photo_any_file_id(photo_);
    case Type::Video:
      return video_file_id_;
    default:
      UNREACHABLE();
      break;
  }
  return FileId();
}

FileId MessageExtendedMedia::get_thumbnail_file_id(const Td *td) const {
  switch (type_) {
    case Type::Empty:
    case Type::Unsupported:
    case Type::Preview:
      break;
    case Type::Photo:
      return get_photo_thumbnail_file_id(photo_);
    case Type::Video:
      return td->videos_manager_->get_video_thumbnail_file_id(video_file_id_);
    default:
      UNREACHABLE();
      break;
  }
  return FileId();
}

FileId MessageExtendedMedia::get_cover_any_file_id() const {
  switch (type_) {
    case Type::Empty:
    case Type::Unsupported:
    case Type::Preview:
    case Type::Photo:
      break;
    case Type::Video:
      return get_photo_any_file_id(photo_);
    default:
      UNREACHABLE();
      break;
  }
  return FileId();
}

void MessageExtendedMedia::update_file_id_remote(FileId file_id) {
  if (file_id.get_remote() == 0 || type_ != Type::Video) {
    return;
  }
  if (video_file_id_ == file_id && video_file_id_.get_remote() == 0) {
    video_file_id_ = file_id;
  }
}

const Photo *MessageExtendedMedia::get_video_cover() const {
  switch (type_) {
    case Type::Empty:
    case Type::Unsupported:
    case Type::Preview:
    case Type::Photo:
      break;
    case Type::Video:
      return &photo_;
    default:
      UNREACHABLE();
      break;
  }
  return nullptr;
}

telegram_api::object_ptr<telegram_api::InputMedia> MessageExtendedMedia::get_input_media(
    Td *td, telegram_api::object_ptr<telegram_api::InputFile> input_file,
    telegram_api::object_ptr<telegram_api::InputFile> input_thumbnail) const {
  switch (type_) {
    case Type::Empty:
    case Type::Unsupported:
    case Type::Preview:
      break;
    case Type::Photo:
      return photo_get_input_media(td->file_manager_.get(), photo_, std::move(input_file), 0, false);
    case Type::Video:
      return td->videos_manager_->get_input_media(video_file_id_, std::move(input_file), std::move(input_thumbnail),
                                                  photo_, start_timestamp_, 0, false);
    default:
      UNREACHABLE();
      break;
  }
  return nullptr;
}

void MessageExtendedMedia::merge_files(Td *td, MessageExtendedMedia &other, DialogId dialog_id, bool need_merge_files,
                                       bool &is_content_changed, bool &need_update) const {
  if (!has_input_media() || !other.has_input_media()) {
    return;
  }
  if (type_ != other.type_) {
    LOG(ERROR) << "Type of paid media has changed";
    return;
  }
  switch (type_) {
    case Type::Photo:
      merge_photos(td, &photo_, &other.photo_, dialog_id, need_merge_files, is_content_changed, need_update);
      break;
    case Type::Video:
      if (video_file_id_ != other.video_file_id_ && need_merge_files) {
        td->videos_manager_->merge_videos(other.video_file_id_, video_file_id_);
      }
      break;
    case Type::Empty:
    case Type::Preview:
    case Type::Unsupported:
    default:
      UNREACHABLE();
      break;
  }
}

bool MessageExtendedMedia::is_equal_but_different(const MessageExtendedMedia &other) const {
  return type_ == Type::Unsupported && other.type_ == Type::Unsupported &&
         unsupported_version_ != other.unsupported_version_;
}

bool operator==(const MessageExtendedMedia &lhs, const MessageExtendedMedia &rhs) {
  if (lhs.type_ != rhs.type_) {
    return false;
  }
  switch (lhs.type_) {
    case MessageExtendedMedia::Type::Empty:
      return true;
    case MessageExtendedMedia::Type::Unsupported:
      // don't compare unsupported_version_
      return true;
    case MessageExtendedMedia::Type::Preview:
      return lhs.duration_ == rhs.duration_ && lhs.dimensions_ == rhs.dimensions_ &&
             lhs.minithumbnail_ == rhs.minithumbnail_;
    case MessageExtendedMedia::Type::Photo:
      return lhs.photo_ == rhs.photo_;
    case MessageExtendedMedia::Type::Video:
      return lhs.video_file_id_ == rhs.video_file_id_ && lhs.photo_ == rhs.photo_ &&
             lhs.start_timestamp_ == rhs.start_timestamp_;
    default:
      UNREACHABLE();
      return true;
  }
}

bool operator!=(const MessageExtendedMedia &lhs, const MessageExtendedMedia &rhs) {
  return !(lhs == rhs);
}

}  // namespace td
