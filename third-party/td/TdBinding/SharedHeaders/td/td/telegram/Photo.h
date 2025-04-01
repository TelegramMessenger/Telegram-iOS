//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/DialogId.h"
#include "td/telegram/EncryptedFile.h"
#include "td/telegram/files/FileId.h"
#include "td/telegram/files/FileType.h"
#include "td/telegram/PhotoSize.h"
#include "td/telegram/secret_api.h"
#include "td/telegram/SecretInputMedia.h"
#include "td/telegram/StickerPhotoSize.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"
#include "td/telegram/UserId.h"

#include "td/utils/buffer.h"
#include "td/utils/common.h"
#include "td/utils/MovableValue.h"
#include "td/utils/Status.h"
#include "td/utils/StringBuilder.h"
#include "td/utils/unique_value_ptr.h"

namespace td {

class FileManager;
class Td;

struct DialogPhoto {
  FileId small_file_id;
  FileId big_file_id;
  string minithumbnail;
  bool has_animation = false;
  bool is_personal = false;
};

struct ProfilePhoto final : public DialogPhoto {
  int64 id = 0;
};

struct Photo {
  MovableValue<int64, -2> id;
  int32 date = 0;
  string minithumbnail;
  vector<PhotoSize> photos;

  vector<AnimationSize> animations;

  unique_value_ptr<StickerPhotoSize> sticker_photo_size;

  bool has_stickers = false;
  vector<FileId> sticker_file_ids;

  bool is_empty() const {
    return id.get() == -2;
  }

  bool is_bad() const {
    if (is_empty()) {
      return true;
    }
    for (auto &photo_size : photos) {
      if (!photo_size.file_id.is_valid()) {
        return true;
      }
    }
    return false;
  }
};

int64 get_profile_photo_id(const tl_object_ptr<telegram_api::UserProfilePhoto> &profile_photo_ptr);

ProfilePhoto get_profile_photo(FileManager *file_manager, UserId user_id, int64 user_access_hash,
                               tl_object_ptr<telegram_api::UserProfilePhoto> &&profile_photo_ptr);
tl_object_ptr<td_api::profilePhoto> get_profile_photo_object(FileManager *file_manager,
                                                             const ProfilePhoto &profile_photo);

bool need_update_profile_photo(const ProfilePhoto &from, const ProfilePhoto &to);

StringBuilder &operator<<(StringBuilder &string_builder, const ProfilePhoto &profile_photo);

DialogPhoto get_dialog_photo(FileManager *file_manager, DialogId dialog_id, int64 dialog_access_hash,
                             telegram_api::object_ptr<telegram_api::ChatPhoto> &&chat_photo_ptr);

tl_object_ptr<td_api::chatPhotoInfo> get_chat_photo_info_object(FileManager *file_manager,
                                                                const DialogPhoto *dialog_photo);

DialogPhoto as_fake_dialog_photo(const Photo &photo, DialogId dialog_id, bool is_personal);

DialogPhoto as_dialog_photo(FileManager *file_manager, DialogId dialog_id, int64 dialog_access_hash, const Photo &photo,
                            bool is_personal);

ProfilePhoto as_profile_photo(FileManager *file_manager, UserId user_id, int64 user_access_hash, const Photo &photo,
                              bool is_personal);

bool is_same_dialog_photo(FileManager *file_manager, DialogId dialog_id, const Photo &photo,
                          const DialogPhoto &dialog_photo, bool is_personal);

vector<FileId> dialog_photo_get_file_ids(const DialogPhoto &dialog_photo);

bool need_update_dialog_photo(const DialogPhoto &from, const DialogPhoto &to);

StringBuilder &operator<<(StringBuilder &string_builder, const DialogPhoto &dialog_photo);

Photo get_photo(Td *td, tl_object_ptr<telegram_api::Photo> &&photo, DialogId owner_dialog_id,
                FileType file_type = FileType::Photo);

Photo get_photo(Td *td, tl_object_ptr<telegram_api::photo> &&photo, DialogId owner_dialog_id,
                FileType file_type = FileType::Photo);

Photo get_encrypted_file_photo(FileManager *file_manager, unique_ptr<EncryptedFile> &&file,
                               tl_object_ptr<secret_api::decryptedMessageMediaPhoto> &&photo, DialogId owner_dialog_id);

Photo get_web_document_photo(FileManager *file_manager, tl_object_ptr<telegram_api::WebDocument> web_document,
                             DialogId owner_dialog_id);

Result<Photo> create_photo(FileManager *file_manager, FileId file_id, PhotoSize &&thumbnail, int32 width, int32 height,
                           vector<FileId> &&sticker_file_ids);

Photo dup_photo(Photo photo);

tl_object_ptr<td_api::photo> get_photo_object(FileManager *file_manager, const Photo &photo);

tl_object_ptr<td_api::chatPhoto> get_chat_photo_object(FileManager *file_manager, const Photo &photo);

void merge_photos(Td *td, const Photo *old_photo, Photo *new_photo, DialogId dialog_id, bool need_merge_files,
                  bool &is_content_changed, bool &need_update);

void photo_delete_thumbnail(Photo &photo);

FileId get_photo_any_file_id(const Photo &photo);

FileId get_photo_thumbnail_file_id(const Photo &photo);

SecretInputMedia photo_get_secret_input_media(FileManager *file_manager, const Photo &photo,
                                              telegram_api::object_ptr<telegram_api::InputEncryptedFile> input_file,
                                              const string &caption, BufferSlice thumbnail);

tl_object_ptr<telegram_api::InputMedia> photo_get_input_media(
    FileManager *file_manager, const Photo &photo, telegram_api::object_ptr<telegram_api::InputFile> input_file,
    int32 ttl, bool has_spoiler);

telegram_api::object_ptr<telegram_api::InputMedia> photo_get_cover_input_media(FileManager *file_manager,
                                                                               const Photo &photo, bool force,
                                                                               bool allow_external);

vector<FileId> photo_get_file_ids(const Photo &photo);

bool operator==(const Photo &lhs, const Photo &rhs);
bool operator!=(const Photo &lhs, const Photo &rhs);

StringBuilder &operator<<(StringBuilder &string_builder, const Photo &photo);

telegram_api::object_ptr<telegram_api::userProfilePhoto> convert_photo_to_profile_photo(
    const telegram_api::object_ptr<telegram_api::photo> &photo, bool is_personal);

}  // namespace td
