//
// Copyright Aliaksei Levin (levlam@telegram.org), Arseny Smirnov (arseny30@gmail.com) 2014-2025
//
// Distributed under the Boost Software License, Version 1.0. (See accompanying
// file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
//
#pragma once

#include "td/telegram/td_api.h"

#include "td/utils/common.h"
#include "td/utils/Slice.h"
#include "td/utils/StringBuilder.h"

namespace td {

enum class FileType : int32 {
  Thumbnail,
  ProfilePhoto,
  Photo,
  VoiceNote,
  Video,
  Document,
  Encrypted,
  Temp,
  Sticker,
  Audio,
  Animation,
  EncryptedThumbnail,
  Wallpaper,
  VideoNote,
  SecureDecrypted,
  SecureEncrypted,
  Background,
  DocumentAsFile,
  Ringtone,
  CallLog,
  PhotoStory,
  VideoStory,
  SelfDestructingPhoto,
  SelfDestructingVideo,
  SelfDestructingVideoNote,
  SelfDestructingVoiceNote,
  Size,
  None
};

enum class FileDirType : int8 { Secure, Common };

constexpr int32 MAX_FILE_TYPE = static_cast<int32>(FileType::Size);

FileType get_file_type(const td_api::FileType &file_type);

tl_object_ptr<td_api::FileType> get_file_type_object(FileType file_type);

FileType get_main_file_type(FileType file_type);

CSlice get_file_type_name(FileType file_type);

CSlice get_file_type_unique_name(FileType file_type);

enum class FileTypeClass : int32 { Photo, Document, Secure, Encrypted, Temp };

FileTypeClass get_file_type_class(FileType file_type);

bool is_document_file_type(FileType file_type);

StringBuilder &operator<<(StringBuilder &string_builder, FileType file_type);

FileDirType get_file_dir_type(FileType file_type);

bool is_file_big(FileType file_type, int64 expected_size);

bool can_reuse_remote_file(FileType file_type);

FileType guess_file_type_by_path(Slice file_path, FileType default_file_type = FileType::None);

}  // namespace td
