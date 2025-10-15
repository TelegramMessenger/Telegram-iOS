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
#include "td/telegram/Photo.h"
#include "td/telegram/td_api.h"
#include "td/telegram/telegram_api.h"

#include "td/utils/common.h"
#include "td/utils/Status.h"

namespace td {

class MessageContent;

class Td;

class MessageExtendedMedia {
  enum class Type : int32 { Empty, Unsupported, Preview, Photo, Video };
  Type type_ = Type::Empty;

  static constexpr int32 CURRENT_VERSION = 1;

  // for Unsupported
  int32 unsupported_version_ = 0;

  // for Preview
  int32 duration_ = 0;
  Dimensions dimensions_;
  string minithumbnail_;

  // for Photo and Video cover
  Photo photo_;

  // for Video
  FileId video_file_id_;
  int32 start_timestamp_ = 0;

  friend bool operator==(const MessageExtendedMedia &lhs, const MessageExtendedMedia &rhs);

  void init_from_media(Td *td, telegram_api::object_ptr<telegram_api::MessageMedia> &&media, DialogId owner_dialog_id);

  bool is_media() const {
    return type_ != Type::Empty && type_ != Type::Preview;
  }

 public:
  MessageExtendedMedia() = default;

  MessageExtendedMedia(Td *td, telegram_api::object_ptr<telegram_api::MessageExtendedMedia> &&extended_media,
                       DialogId owner_dialog_id);

  MessageExtendedMedia(Td *td, telegram_api::object_ptr<telegram_api::MessageMedia> &&media, DialogId owner_dialog_id);

  static Result<MessageExtendedMedia> get_message_extended_media(
      Td *td, td_api::object_ptr<td_api::inputPaidMedia> &&paid_media, DialogId owner_dialog_id);

  bool is_empty() const {
    return type_ == Type::Empty;
  }

  bool has_input_media() const {
    return type_ == Type::Photo || type_ == Type::Video;
  }

  void update_from(const MessageExtendedMedia &old_extended_media);

  bool update_to(Td *td, telegram_api::object_ptr<telegram_api::MessageExtendedMedia> extended_media_ptr,
                 DialogId owner_dialog_id);

  td_api::object_ptr<td_api::PaidMedia> get_paid_media_object(Td *td) const;

  void append_file_ids(const Td *td, vector<FileId> &file_ids) const;

  void delete_thumbnail(Td *td);

  bool is_unsupported() const {
    return type_ == Type::Unsupported;
  }

  bool need_reget() const {
    return type_ == Type::Unsupported && unsupported_version_ < CURRENT_VERSION;
  }

  bool need_poll() const {
    return type_ == Type::Preview;
  }

  bool has_media_timestamp() const {
    return type_ == Type::Video;
  }

  bool is_equal_but_different(const MessageExtendedMedia &other) const;

  unique_ptr<MessageContent> get_message_content() const;

  int32 get_duration(const Td *td) const;

  FileId get_any_file_id() const;

  FileId get_thumbnail_file_id(const Td *td) const;

  FileId get_cover_any_file_id() const;

  void update_file_id_remote(FileId file_id);

  const Photo *get_video_cover() const;

  telegram_api::object_ptr<telegram_api::InputMedia> get_input_media(
      Td *td, telegram_api::object_ptr<telegram_api::InputFile> input_file,
      telegram_api::object_ptr<telegram_api::InputFile> input_thumbnail) const;

  void merge_files(Td *td, MessageExtendedMedia &other, DialogId dialog_id, bool need_merge_files,
                   bool &is_content_changed, bool &need_update) const;

  template <class StorerT>
  void store(StorerT &storer) const;

  template <class ParserT>
  void parse(ParserT &parser);
};

bool operator==(const MessageExtendedMedia &lhs, const MessageExtendedMedia &rhs);

bool operator!=(const MessageExtendedMedia &lhs, const MessageExtendedMedia &rhs);

}  // namespace td
