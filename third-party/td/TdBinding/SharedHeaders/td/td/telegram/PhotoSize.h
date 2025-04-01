//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/DialogId.h"
#include "td/telegram/Dimensions.h"
#include "td/telegram/files/FileId.h"
#include "td/telegram/files/FileType.h"
#include "td/telegram/net/DcId.h"
#include "td/telegram/PhotoFormat.h"
#include "td/telegram/PhotoSizeSource.h"
#include "td/telegram/PhotoSizeType.h"
#include "td/telegram/StickerPhotoSize.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"

#include "td/utils/buffer.h"
#include "td/utils/common.h"
#include "td/utils/Status.h"
#include "td/utils/StringBuilder.h"
#include "td/utils/Variant.h"

namespace td {

class FileManager;
class Td;

struct PhotoSize {
  PhotoSizeType type;
  int32 size = 0;
  Dimensions dimensions;
  FileId file_id;
  vector<int32> progressive_sizes;
};

struct AnimationSize final : public PhotoSize {
  double main_frame_timestamp = 0.0;
};

bool need_update_dialog_photo_minithumbnail(const string &from, const string &to);

td_api::object_ptr<td_api::minithumbnail> get_minithumbnail_object(const string &packed);

FileId register_photo_size(FileManager *file_manager, const PhotoSizeSource &source, int64 id, int64 access_hash,
                           string file_reference, DialogId owner_dialog_id, int32 file_size, DcId dc_id,
                           PhotoFormat format, const char *call_source);

PhotoSize get_secret_thumbnail_photo_size(FileManager *file_manager, BufferSlice bytes, DialogId owner_dialog_id,
                                          int32 width, int32 height);

Variant<PhotoSize, string> get_photo_size(FileManager *file_manager, PhotoSizeSource source, int64 id,
                                          int64 access_hash, string file_reference, DcId dc_id,
                                          DialogId owner_dialog_id, tl_object_ptr<telegram_api::PhotoSize> &&size_ptr,
                                          PhotoFormat format);

AnimationSize get_animation_size(Td *td, PhotoSizeSource source, int64 id, int64 access_hash, string file_reference,
                                 DcId dc_id, DialogId owner_dialog_id, tl_object_ptr<telegram_api::videoSize> &&size);

Variant<AnimationSize, unique_ptr<StickerPhotoSize>> process_video_size(
    Td *td, PhotoSizeSource source, int64 id, int64 access_hash, string file_reference, DcId dc_id,
    DialogId owner_dialog_id, tl_object_ptr<telegram_api::VideoSize> &&size_ptr);

PhotoSize get_web_document_photo_size(FileManager *file_manager, FileType file_type, DialogId owner_dialog_id,
                                      tl_object_ptr<telegram_api::WebDocument> web_document_ptr);

Result<PhotoSize> get_input_photo_size(FileManager *file_manager, FileId file_id, int32 width, int32 height);

PhotoSize get_input_thumbnail_photo_size(FileManager *file_manager, const td_api::inputThumbnail *input_thumbnail,
                                         DialogId dialog_id, bool is_secret);

td_api::object_ptr<td_api::thumbnail> get_thumbnail_object(FileManager *file_manager, const PhotoSize &photo_size,
                                                           PhotoFormat format);

bool operator==(const PhotoSize &lhs, const PhotoSize &rhs);
bool operator!=(const PhotoSize &lhs, const PhotoSize &rhs);

bool operator<(const PhotoSize &lhs, const PhotoSize &rhs);

StringBuilder &operator<<(StringBuilder &string_builder, const PhotoSize &photo_size);

bool operator==(const AnimationSize &lhs, const AnimationSize &rhs);
bool operator!=(const AnimationSize &lhs, const AnimationSize &rhs);

StringBuilder &operator<<(StringBuilder &string_builder, const AnimationSize &animation_size);

}  // namespace td
